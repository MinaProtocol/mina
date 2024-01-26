from collections import defaultdict
import json
import pydot

# TODO: when a node has multiple successors, we need to subtract out the other threads


def thread_time_query(thread):
    return (
        'sum by(app) (rate(Mina_Daemon_time_spent_in_thread_%s_ms{testnet="$testnet",app="$app"}[$sample_range]))'
        % thread
    )


def isolated_thread_time_query(child_index, thread):
    if not thread in child_index:
        raise Exception('thread not found in graph: %s' % thread)
    query = thread_time_query(thread)
    child_queries = [
        "sum(%s or vector(0))" % thread_time_query(child)
        for child in child_index[thread]
    ]
    if len(child_queries) > 0:
        return "sum(%s or vector(0))-(%s)" % (query, "+".join(child_queries))
    else:
        return query


def grafana_thread_target(child_index, thread, isolate):
    expr = isolated_thread_time_query(child_index, thread) if isolate else thread_time_query(thread)
    return {
        # "datasource": {"type": "prometheus", "uid": "grafanacloud-prom"},
        "datasource": None,
        "exemplar": True,
        "expr": expr,
        "hide": False,
        "interval": "",
        "legendFormat": thread,
        "refId": thread,
    }


def grafana_chart_targets(child_index, root, max_depth=None):
    is_leaf = (max_depth == 0)

    targets = []
    targets.append(grafana_thread_target(child_index, root, isolate=not is_leaf))

    if not is_leaf:
        for child in child_index[root]:
            targets.extend(grafana_chart_targets(child_index, child, max_depth - 1 if max_depth != None else None))

    return targets


def grafana_panel(child_index, root, max_depth=None):
    targets = grafana_chart_targets(child_index, root, max_depth)
    defaults = {
        "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "barAlignment": 0,
            "lineWidth": 1,
            "fillOpacity": 100,
            "gradientMode": "none",
            "spanNulls": False,
            "showPoints": "never",
            "pointSize": 5,
            "stacking": {"mode": "normal", "group": root},
            "axisPlacement": "auto",
            "axisLabel": "",
            "scaleDistribution": {"type": "linear"},
            "hideFrom": {"tooltip": False, "viz": False, "legend": False},
            "thresholdsStyle": {"mode": "off"},
            "lineStyle": {"fill": "solid"},
        },
        "color": {"mode": "palette-classic"},
        "mappings": [],
        "thresholds": {
            "mode": "absolute",
            "steps": [
                {"color": "green", "value": None},
                {"color": "red", "value": 80},
            ],
        },
        "min": 0,
        "unit": "ms",
    }
    return {
        "id": 0,
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 14},
        "type": "timeseries",
        "title": root,
        # "datasource": {"type": "prometheus", "uid": "grafanacloud-prom"},
        "datasource": None,
        "defaults": defaults,
        "fieldConfig": {
            "defaults": defaults,
            "overrides": []
        },
        "options": {
            "tooltip": {"mode": "single", "sort": "none"},
            "legend": {"displayMode": "list", "placement": "bottom", "calcs": []},
        },
        "targets": targets,
    }

graph = pydot.graph_from_dot_file("coordinator-threads.dot")[0]
child_index = {}
for v in graph.get_nodes():
    child_index[v.obj_dict['name']] = []
for e in graph.get_edges():
    (pred, succ) = e.obj_dict["points"]
    child_index[pred].append(succ)

print(json.dumps(grafana_panel(child_index, "serve_client_rpcs", max_depth=None)))
