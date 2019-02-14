#[macro_use]
extern crate nom;
extern crate clap;
extern crate memmap;

use std::collections::HashMap;
use std::io::prelude::*;

use clap::{App, Arg};
use nom::{le_u64, le_u8};

#[derive(Copy, Clone, Debug, Hash, PartialOrd, PartialEq, Eq)]
struct Tid(u64);

#[derive(Clone, Debug)]
enum EventKind {
    New(Tid, String),
    Switch(Tid),
    CycleStart,
    CycleEnd,
    Pid(u64),
    Event(String),
    Start(String),
    End,
    TraceEnd
}

#[derive(Clone, Debug)]
struct TraceEvent {
    ns_since_epoch: f64,
    data: EventKind,
}

use EventKind::*;

named!(parse_trace_event<&[u8], TraceEvent>,
       switch!(le_u8,
       0 => do_parse!(ns: le_u64 >> tid: le_u64 >> 
                          s: length_data!(le_u64) >>
                          (TraceEvent {
                              ns_since_epoch: ns as f64,
                              data: EventKind::New(Tid(tid),
                              String::from_utf8(s.into()).unwrap())
                            })) |
       1 => do_parse!(ns: le_u64 >> tid: le_u64 >>
                      (TraceEvent {
                          ns_since_epoch: ns as f64,
                          data: EventKind::Switch(Tid(tid))
                        })) |
        2 => do_parse!(ns: le_u64 >> (TraceEvent {
            ns_since_epoch: ns as f64,
            data: CycleStart
        })) |
        3 => do_parse!(ns: le_u64 >> (TraceEvent {
            ns_since_epoch: ns as f64,
            data: CycleEnd
        })) |
        4 => do_parse!(pid: le_u64 >> (TraceEvent {
            ns_since_epoch: 0.0,
            data: Pid(pid)
        })) |
        5 => do_parse!(ns: le_u64 >> s: length_data!(le_u64) >> (TraceEvent {
            ns_since_epoch: ns as f64,
            data: Event(String::from_utf8(s.into()).unwrap())
        })) |
        6 => do_parse!(ns: le_u64 >> s: length_data!(le_u64) >> (TraceEvent {
            ns_since_epoch: ns as f64,
            data: Start(String::from_utf8(s.into()).unwrap())
        })) |
        7 => do_parse!(ns: le_u64 >> (TraceEvent {
            ns_since_epoch: ns as f64,
            data: End
        })) |
        8 => do_parse!(ns: le_u64 >> (TraceEvent {
            ns_since_epoch: ns as f64,
            data: TraceEnd
        }))
        ));

named!(parse_trace_events<&[u8], Vec<Option<TraceEvent> > >,
       many0!(complete!(opt!(call!(parse_trace_event)))));

fn complete_event(
    tids: &HashMap<Tid, String>,
    pid: u64,
    cur_ts: f64,
    prev_ts: f64,
    prev_task: Option<Tid>,
) {
    assert!(pid != 0);
    match prev_task {
        Some(tid) => match tids.get(&tid) {
            Some(tname) => println!(
                r#"{{"name":"{}","pid":{},"ph":"X","ts":{},"dur":{},"tid":{}}},"#,
                tname,
                pid,
                prev_ts / 1000.0,
                (cur_ts - prev_ts) / 1000.0,
                tid.0
            ),
            None => println!(
                r#"{{"name":"{}","pid":{},"ph":"X","ts":{},"dur":{},"tid":{}}},"#,
                "unnamed task",
                pid,
                prev_ts / 1000.0,
                (cur_ts - prev_ts) / 1000.0,
                tid.0
            ),
        },
        None => {}
    }
}

fn main() {
    let matches = App::new("trace-tool")
        .arg(
            Arg::with_name("input")
                .help("file to read trace data from")
                .multiple(true)
                .required(true),
        )
        .get_matches();
    let inputs = matches.values_of("input").unwrap();
    println!("[");
    let mut contents = Vec::new();
    for filename in inputs {
        contents.clear();
        std::fs::File::open(filename)
            .unwrap()
            .read_to_end(&mut contents)
            .unwrap();
        let mut seen_tids = HashMap::<Tid, String>::new();
        let mut recurring_map = HashMap::<String, Tid>::new();
        let mut tidmap = HashMap::<Tid, Tid>::new();
        let mut cur_pid = 0;
        match parse_trace_events(contents.as_ref()) {
            Ok((_, events)) => {
                let prev_ts = match events.first() {
                    Some(Some(e)) => e.ns_since_epoch,
                    _ => 0.0,
                };
                let mut cycle_start_ts = 0.0;
                let _ = events.into_iter().filter_map(|x| x).fold(
                    (prev_ts, None),
                    |(prev_ts, prev_task), event| {
                        let cur_ts = event.ns_since_epoch;
                        match event.data {
                            New(t, s) => {
                                if s.starts_with("R&") {
                                    let real = recurring_map.entry(s.clone()).or_insert(t);
                                    tidmap.insert(t, *real);
                                }
                                println!(r#"{{"name":"thread_name","ph":"M","pid":{},"tid":{},"args":{{"name":"{}"}}}},"#, cur_pid, t.0, s);
                                seen_tids.insert(t, s);
                                (prev_ts, prev_task)
                            }
                            Switch(t) => {
                                let prev_task = prev_task.and_then(|t| tidmap.get(&t).map(|x| *x)).or(prev_task);
                                complete_event(&seen_tids, cur_pid, cur_ts, prev_ts, prev_task);
                                (cur_ts, tidmap.get(&t).map(|x| *x).or(Some(t)))
                            }
                            CycleStart => {
                                cycle_start_ts = cur_ts;
                                (cur_ts, prev_task)
                            }
                            TraceEnd | CycleEnd => {
                                // if the cycle is reported as ending, then whatever thread was running just finished.
                                complete_event(&seen_tids, cur_pid, cur_ts, prev_ts, prev_task);
                                if let TraceEnd = event.data {
                                    seen_tids.clear();
                                    recurring_map.clear();
                                    tidmap.clear();
                                }
                                (cur_ts, None)
                                //println!(r#"{{"name":"cycle end","ph":"p","ts":{},"pid":1,"tid":0,"s":"p"}},"#, cur_ts/1000);
                            }
                            Pid(pid) => {
                                println!(r#"{{"name":"thread_name","ph":"M","pid":{},"tid":0,"args":{{"name":"unlabeled async"}}}},"#, pid);
                                cur_pid = pid;
                                (prev_ts, prev_task)
                            }
                            Event(s) => {
                                println!(r#"{{"name":"{}","ph":"i","ts":{},"pid":{},"tid":{},"s":"t"}},"#, s, cur_ts/1000.0, cur_pid, prev_task.unwrap_or(Tid(0)).0);
                                (prev_ts, prev_task)
                            }
                            Start(s) => {
                                println!(
                                    r#"{{"name":"{}","ph":"B","ts":{},"pid":{},"tid":{}}},"#,
                                    s,
                                    cur_ts / 1000.0,
                                    cur_pid,
                                    prev_task.unwrap_or(Tid(0)).0
                                );
                                (prev_ts, prev_task)
                            }
                            End => {
                                println!(
                                    r#"{{"ph":"E","ts":{},"pid":{},"tid":{}}},"#,
                                    cur_ts / 1000.0,
                                    cur_pid,
                                    prev_task.unwrap_or(Tid(0)).0
                                );
                                (prev_ts, prev_task)
                            }
                        }
                    },
                );
            }
            Err(e) => panic!("parsing failed {:?}", e),
        }
    }
}
