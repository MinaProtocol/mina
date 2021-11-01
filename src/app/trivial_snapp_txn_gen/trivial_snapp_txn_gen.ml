open Core
open Async
open Mina_base

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

(*let graphql_snapp_command parties =
let a =
    sprintf
      {|
        snappProtocolState: {
      nextEpochData: {
        epochLength: {checkOrIgnore: Ignore}, 
        lockCheckpoint: {checkOrIgnore: Ignore}, 
        startCheckpoint: {checkOrIgnore: Ignore}, 
        seed: {checkOrIgnore: Ignore}, 
        ledger: {
          totalCurrency: {checkOrIgnore: Ignore}, 
          hash: {checkOrIgnore: Ignore}}}, 
      stakingEpochData: {
        epochLength: {checkOrIgnore: Ignore}, 
        lockCheckpoint: {checkOrIgnore: Ignore}, 
        startCheckpoint: {checkOrIgnore: Ignore}, 
        seed: {checkOrIgnore: Ignore}, 
        ledger: {
          totalCurrency: {checkOrIgnore: Ignore}, 
          hash: {checkOrIgnore: Ignore}}}, 
      globalSlotSinceGenesis: {checkOrIgnore: Ignore}, 
      globalSlotSinceHardFork: {checkOrIgnore: Ignore}, 
      totalCurrency: {checkOrIgnore: Ignore}, 
      minWindowDensity: {checkOrIgnore: Ignore}, 
      blockchainLength: {checkOrIgnore: Ignore}, 
      timestamp: {checkOrIgnore: Ignore}, 
      snarkedNextAvailableToken: {checkOrIgnore: Ignore}, 
      snarkedLedgerHash: {checkOrIgnore: Ignore}}, 
    snappOtherParties: [{
      authorization: {proofOrSignature: Signature, signature:"%s"}, 
      data: {
        predicate: {fullOrNonceOrAccept: Nonce, nonce:"1"}, 
        body: {
          depth: "0", 
          callData: "0x0000000000000000000000000000000000000000000000000000000000000000", 
          rollupEvents: [], 
          events: [], 
          delta: {sgn: MINUS, magnitude: "10000000000"}, 
          tokenId: "1", 
          update: {
            timing: {setOrKeep: Keep}, 
            tokenSymbol: {setOrKeep: Keep}, 
            snappUri: {setOrKeep: Keep}, 
            permissions: {setOrKeep: Keep}, 
            verificationKey: {setOrKeep: Keep}, 
            delegate: {setOrKeep: Keep}, 
            appState: [
          {setOrKeep: Keep} ,
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep}]}, 
          pk: "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"}}},{
      authorization: {proofOrSignature: Proof, proof: "KChzdGF0ZW1lbnQoKHByb29mX3N0YXRlKChkZWZlcnJlZF92YWx1ZXMoKHBsb25rKChhbHBoYShTY2FsYXJfY2hhbGxlbmdlKDZmNDBhZDgwZDhmMTE0ZWQgMGFkOWYzYzI0YTEzOWRiYSkpKShiZXRhKDFiZjI5M2U3YWZkMDRhNzcgN2RlZjk3MjRhYmMwYTExNykpKGdhbW1hKDBlYzI5M2I2NWNlYWU3YzUgMDc4ZWZkNzYwMjk0NTc3NSkpKHpldGEoU2NhbGFyX2NoYWxsZW5nZShhYTQxYTAwNTdlZjRlZDUyIGE3MTM1MDgwMDIyNGJhMmIpKSkpKShjb21iaW5lZF9pbm5lcl9wcm9kdWN0KFNoaWZ0ZWRfdmFsdWUgMHg1MDY0ZDY2YWRlNTI5YzY2MWE4NWRhMWUwZDU5ZDcwNzM3MmM1NzhkYmJhOTZlMmU2YTljZWMxOWI2MmQwMTBiKSkoYihTaGlmdGVkX3ZhbHVlIDB4MzczNjZmODM1ZjNkMWMwZGZkYTc0ZTVhZjZmNjMyN2JlZWM3YTU4NzNhOTJiZGZiNzMyOTUyMzNmNTg3MTAyZSkpKHhpKFNjYWxhcl9jaGFsbGVuZ2UoOWJjNDAzMWFlZjI3OTQwOCA3Njg2NGI5Y2I4NTc5YTcyKSkpKGJ1bGxldHByb29mX2NoYWxsZW5nZXMoKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgwM2VmNDgyMTQzOWE5Mzg5IGZkNGUwYjI0NGFiMWExY2MpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShhOWE1NDViMzc5Y2M0MjkxIGZhNDc5OTk4NTJmNDQwYTMpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg3ZTI0ZWFiMWJlM2Y3MWMwIDIzN2VlOTg3NGUzNDdkYmIpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShiNzQ0NjdhNjJjZmI4NGYwIGQ5YzkxNjVkNGYxNmFmNjApKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg4NjdlNDE0ZWRlMjk4MWMyIGMyYTIwMjFlMThjZmYyZjQpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg4MzQ2OTM4ZjhiZTdlYTdhIDU0ZjcyYjY0NTBhZDVlYjQpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShkMjRmMzQ1ZDY0M2Y1MzQzIGM0MTVkYWQ0YjQ1ZTU1NjMpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgwOTk2MTM0MTZiNGEzZDZiIGIzYmZlODZhOGRmNWMzNzMpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg4NzI2ZGY0OGRkZDg3YzIxIDgyZWU4MDkxZjJhMzhmMjcpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShmYzUxZGI1YjZiZDIxMmJiIGZlNGQxMjMyYmQ3MTgzOGEpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg5ODc1ODA5MWVlYmNiOTcxIDQ4MTg2NjI5ZDI3ZDI4ZWYpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgyYTI3ZDQ0ZGY1MmYwYmQ3IGNlMTZiODcwY2QwZWFhNzcpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShjYzI2NjMwMDdmM2UzM2JhIGZhZmQ1ZjdkMmNmNGE2YTgpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShjN2VmYzJiNzc4OWJiMTI3IGYzMzkzNGViMzQ0MmRlYjgpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg0MDgwODM5NWU2ODYwYWJiIGVjN2M0YjMwYjE3ODUxZWIpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShiNTZhN2FkMTc2YjljZGUxIDkxZmY4NDdjYmJkMWMwOGIpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg1MjI5YjhmNTY2YWIyY2NjIGJiMzQyZmEzNWE1YWI3OWEpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgzYWMwMTlmNzA0M2M0NzE3IGZlOGFlNjExZWJmMjBmYzIpKSkpKSkod2hpY2hfYnJhbmNoIlwwMDAiKSkpKHNwb25nZV9kaWdlc3RfYmVmb3JlX2V2YWx1YXRpb25zKDhhNGYyYmVhZjBkOTE2MDQgZThmMjY3M2YyYTk4YzBkZiAyN2Q3NjhmNzkwZmNmYTBiIDA5OTA5YmU0NzAzNDAwMjkpKShtZV9vbmx5KChzZygweDkyMjJiOWJkYzc0NGRiZjBmMDQ1ZjA5NDBhMzhkZThlZmY5ZDM2YmJmNWJmNmYzYTgxMDJlZWNmYTA0MGZkMmEgMHg1ZTIzYWZjMWZmMmVlMGY3OWRiOWU3NWUyYTIxOTkwYzExNTA4NmU2MmE5MDg5Njc3Y2ZjMDczOGQ5NzM5YTEyKSkob2xkX2J1bGxldHByb29mX2NoYWxsZW5nZXMoKCgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoYzY3MGI3MTJiODMxNzUxMyAxNjc1Y2MzMzlhNDgzZTA4KSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoNDhjMWIwYTJiMWNhYjhkMSAxYjY2MDRlM2MwNzFiMWNlKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoMzM4MmIzYzlhY2U2YmY2ZiA3OTk3NDM1OGY5NzYxODYzKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoZGQzYTJiMDZlOTg4ODc5NyBkZDdhZTY0MDI5NDRhMWM3KSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoYzZlOGU1MzBmNDljOWZjYiAwN2RkYmI2NWNkYTA5Y2RkKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoNTMyYzU5YTI4NzY5MWExMyBhOTIxYmNiMDJhNjU2ZjdiKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoZTI5Yzc3YjE4ZjEwMDc4YiBmODVjNWYwMGRmNmIwY2VlKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoMWRiZGE3MmQwN2IwOWM4NyA0ZDFiOTdlMmU5NWYyNmEwKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoOWM3NTc0N2M1NjgwNWYxMSBhMWZlNjM2OWZhY2VmMWU4KSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoNWMyYjhhZGZkYmU5NjA0ZCA1YThjNzE4Y2YyMTBmNzliKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoMjJjMGIzNWM1MWUwNmI0OCBhNjg4OGI3MzQwYTk2ZGVkKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoOTAwN2Q3YjU1ZTc2NjQ2ZSBjMWM2OGIzOWRiNGU4ZTEyKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoNDQ0NWUzNWUzNzNmMmJjOSA5ZDQwYzcxNWZjOGNjZGU1KSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoNDI5ODgyODQ0YmJjYWE0ZSA5N2E5MjdkN2QwYWZiN2JjKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoOTljYTNkNWJmZmZkNmU3NyBlZmU2NmE1NTE1NWM0Mjk0KSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoNGI3ZGIyNzEyMTk3OTk1NCA5NTFmYTJlMDYxOTNjODQwKSkpKSgocHJlY2hhbGxlbmdlKFNjYWxhcl9jaGFsbGVuZ2UoMmNkMWNjYmViMjA3NDdiMyA1YmQxZGUzY2YyNjQwMjFkKSkpKSkoKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShjNjcwYjcxMmI4MzE3NTEzIDE2NzVjYzMzOWE0ODNlMDgpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg0OGMxYjBhMmIxY2FiOGQxIDFiNjYwNGUzYzA3MWIxY2UpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgzMzgyYjNjOWFjZTZiZjZmIDc5OTc0MzU4Zjk3NjE4NjMpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShkZDNhMmIwNmU5ODg4Nzk3IGRkN2FlNjQwMjk0NGExYzcpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShjNmU4ZTUzMGY0OWM5ZmNiIDA3ZGRiYjY1Y2RhMDljZGQpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg1MzJjNTlhMjg3NjkxYTEzIGE5MjFiY2IwMmE2NTZmN2IpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZShlMjljNzdiMThmMTAwNzhiIGY4NWM1ZjAwZGY2YjBjZWUpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgxZGJkYTcyZDA3YjA5Yzg3IDRkMWI5N2UyZTk1ZjI2YTApKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg5Yzc1NzQ3YzU2ODA1ZjExIGExZmU2MzY5ZmFjZWYxZTgpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg1YzJiOGFkZmRiZTk2MDRkIDVhOGM3MThjZjIxMGY3OWIpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgyMmMwYjM1YzUxZTA2YjQ4IGE2ODg4YjczNDBhOTZkZWQpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg5MDA3ZDdiNTVlNzY2NDZlIGMxYzY4YjM5ZGI0ZThlMTIpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg0NDQ1ZTM1ZTM3M2YyYmM5IDlkNDBjNzE1ZmM4Y2NkZTUpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg0Mjk4ODI4NDRiYmNhYTRlIDk3YTkyN2Q3ZDBhZmI3YmMpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg5OWNhM2Q1YmZmZmQ2ZTc3IGVmZTY2YTU1MTU1YzQyOTQpKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSg0YjdkYjI3MTIxOTc5OTU0IDk1MWZhMmUwNjE5M2M4NDApKSkpKChwcmVjaGFsbGVuZ2UoU2NhbGFyX2NoYWxsZW5nZSgyY2QxY2NiZWIyMDc0N2IzIDViZDFkZTNjZjI2NDAyMWQpKSkpKSkpKSkpKShwYXNzX3Rocm91Z2goKGFwcF9zdGF0ZSgpKShzZygpKShvbGRfYnVsbGV0cHJvb2ZfY2hhbGxlbmdlcygpKSkpKSkocHJldl9ldmFscygoKGwoMHhhMDI0MTczYTQ0YjEwNjhjMmQ0MWI1ZGZiN2QxM2U1MzcxZjMxZWNlOWFkODg1MjM0YTQzYzA2MTk3MGU3MjE1KSkocigweGZhNGU1NDYzMmYxYTQwNzEzMmNjMzM1NmNjNWJkMDQ3MWY3NzdhMGQ4ZDFmNTAzZTAwNzkyYzFkMzJmMTM0MzUpKShvKDB4NjAwNDIyMGYwMzk5MjFlNTk2N2FjN2EwOWY1NGNlNGRjOGNjYjFmN2M2MzBhZTMzODdiZjQ5ZGQwYjk1YzkzOSkpKHooMHgyMGZjYmE0ODc4ZGM2YWNkMTkyMTQ1MjFiOGQ5ZGM5OWY0NGI2MWEzM2IzMTAyYTQ5ZmRiOTQxMWYwMmExZjA3KSkodCgweDFjY2FkOTQ4NTQ1NmNhYzY3ZGI3MmM4M2FjYjJhOTRlYjRhNzEzNGM3YTY3MTBmYjAwMDMwNzYwZmFmNzM3MWQpKShmKDB4M2IxMDRjMjU4YTU2NzA5OTRjNTI1MDllYmFjY2E3MWFhNDFkNzVjNmI0NzQ2ZGI2NjFlYzY4MDdmMGEzMmMzMCkpKHNpZ21hMSgweDIzZmI5ZWE1MDMxMWU4YTdjZjllZTBiNGE0YzI3NDIzMzcxNGQ0MGUzMGM2ZGVhZTcxZjFlMjJmYThmNzJlMzcpKShzaWdtYTIoMHg0ZmEzNDJhM2VhNDRkYjE5NmQ4MzA1NTljZDk5Y2NkYjlmY2RkMTZmMWQ4NzM2MDEzMjg5ZmIwN2ZkYjBjYTE3KSkpKChsKDB4MTlhYzRhMGE4N2VkNjg1ZWFlYzg0OGQxZjczMGIxMjg4OTZmZTA3YzhhMjI0YTBhMWZmMTQyOWM2ZDdjZDYwOCkpKHIoMHg0MDAyY2ZjMmVlZmI3ZTUzOTYxNjEzM2JiY2I5YzFjNjZiNzVhMmQxZGJhNDcxOTNhNTI1NjY2MWRiM2Q0NzM3KSkobygweDZiYzU0NTgwNjg3YzM5NGU5NDI2NGY1ODc4NGVjYmZjMjAwMjNkODcyNDE4OGIzY2NlYWExYjA4ODg0MWUxMTYpKSh6KDB4OWNhYTkyN2MwM2Q4NThjNWNmNWQ4Yzc5MjJhMzQ5MjU5OTdiNjQ3ZTlkMWZkY2FkYmY5MGExZmU1ZDU5MjEwMykpKHQoMHhiZGExMTEwZGI5OTdjYzQwYzQ5ODVhZGJmMDM3MTZlNzRhOGYyYjRiMWUxMjQ2NTMxMmJkNTU0M2MyYmFkODE2KSkoZigweGJlYWVjYjI2NTgwMzBmMjQwNDU5NTkwYzBiNmMxNThiM2M0MjBjYmViYzA3Zjg5NjMxN2JjNTI4NTNhY2RlMDYpKShzaWdtYTEoMHgwNTg4OGM3ZjY2MTNhMmM2NzI0YmI1YTI3ZGEyMjg2NWNlNzM2ODg2ODFkZjlhZjc0OWQ5YWMwYjEwODcxNDAwKSkoc2lnbWEyKDB4M2NmNDkxNWExN2JiMzVlZjNhMjg4NTUwMDE2YzRlM2UxODg5ZWE1YmJjZWZmMzQ5MmJhYjVjZWRkN2U4ZDExMykpKSkpKHByZXZfeF9oYXQoMHhmYTFiOGYzM2VhNmYyNjc3ZWU1Y2Q5ZTE4MGIyZWVhNDg4NTNjNDg2ZmViZDc5MjhmNjIxNWVmYTViODE1MjI5IDB4ZDcxMjI3NGM5MDliNDhkODc3M2Q0ZjIwNTBhMzQwMmVhOGFjMjljNGYxYTNkN2ZhOGRhN2RkZjc5NDdlMmQwYikpKHByb29mKChtZXNzYWdlcygobF9jb21tKCgweDYyMjlmOTRiMDYyODRkMzg4YjJkM2VjOGM4NWZmMGU4ZjNlNmJjZTEyZTAwNzlkZTI4MzYxYTQzMDhhNTVlMGEgMHhlYTlkMjgyYjVjMTI1ODhjNTIzZjEwMDBiYzY5NTIxOGM5YzM1Y2QxYjU1NWYwZjUxMTc2NTg1MTU3M2EyNzAwKSkpKHJfY29tbSgoMHhlZjg0NGRhOTVhNjQ3MmMwN2QwNDgzNmRiOThlYWVjM2Y0MTczMDAzMzg4ZTc2NmQ1YWI5ZDYzOGNhMzIzYTBmIDB4NzNlZTdlMDc4NjZlNWYyY2QyODI3YmMxYzRlZmU0NGI5MmVjZmNiNjcxZGMxOTVkZGY4ODM2NWZkYzY0MTAxMSkpKShvX2NvbW0oKDB4OTMyZDkzZGNmZjI5ODQ1ZDJhNjViZTkyYTkwYTFjMTk5NmVjODBmNjI2NmZmNjcyZjMxZDk3N2RhNDc1OGIxOCAweGU5YWJkOGNlMzE3YzIxYzNlMzYwYjg5MTMyODBjYWMxOGUwNGM4YTM3MDk0Yjk1YTFiNzMwZDAzMjIyZWQxMGYpKSkoel9jb21tKCgweDVhNTk3MWU2YjhhNDJmODg4NzU1MzU5NDI5NWUzMzVhYzk3ZDZjNDM5OGMwMTBiYzkwNDEzOWMzYzU2NGQ4MjYgMHg5ZDdhMTEyM2I5ZGM2ZWViYzlhZThmODI0MDE0ZTQxNDdiMzc4N2NlMDBjOTY3N2FiZTlhMGJjNGM5OTUxMzJiKSkpKHRfY29tbSgodW5zaGlmdGVkKChGaW5pdGUoMHg2NmIxYzQ3NDU5MTJhNTljYWM0NzMzYTkwZDQwMTQwZjI4NDFkYjRmY2FkOWM0NDViYjg2NWIzYzRlYzNmNzEyIDB4MmQ0YmZkNWM5YTRjNzBkYzZhNzRkMTE3Y2VkMDk1NWUyYzllMjNjN2E1MDAyMGU4YzBlMTBkMGY2NzRiZDIyYykpKEZpbml0ZSgweGY4NTUyNjY3YjNhY2JjN2E1MzgwNmVmYTI0YTYxYTVkNjk5MDY1YjhmOGQ5ZmJmMzQ0NGUyNDVkYWE3ZDY5MDYgMHg0NzRlMzA5MDdhNWRmOWJhYWYyZGU1MTRhZmZmMmU0NmNjNTcwZjMxMjY5NGE3M2E4MDI5NmNiYjVlMDI5MTBmKSkoRmluaXRlKDB4ODU3MWRkMGRlMWRkYmM4Y2U1MDIwMzQ0MTE1NmY0NmFkNGI4YTE2ZjlmNjc4ZDFkYjYwYjk5M2ZmN2M4NmYwYyAweGIwOTVlZTVlNGI1YjU5ZjNmZmUzMTE4NzVhMzM1NWRkNTcyYmEzZWEyMzA0NWQ5ZTk2NWM0YTY3MWFjNzNjMTUpKShGaW5pdGUoMHgwYjU3ZjRmMzU3YWVlYzQwYzIyN2NmNmRmNDMyYTBiYTIxNzRiYTBhNTg2ZGQ0ODA5ZGYyZTE4MjI0YjFiMjM0IDB4NjdhNWM1ZmM3OGYyY2MzN2JiNzhkODk5MTM3NTkyMjk1OTg3ZjQ0YzEwNzEwMWQ1YjBlNDdjYjhmNjkyMTczOCkpKEZpbml0ZSgweDM2MTA1ZGY2MDM4YWRlZTU2NjU2ZjMwMGJkZjIxNjQxNWM1Y2NkODdkMDQ2ODgyNWFkZjI5ZDI0NjEwOGVhMGUgMHhmNDVlNmNjZWE4YjIyZjYwOTA5NTgzYzllN2MzZTI2OWNkMDg1ZjFlM2E2NzI3NjM1ZTFhNWFlZjQxMjZmZTEyKSkpKShzaGlmdGVkKEZpbml0ZSgweDQxYWJkMjE5ZWI5Njg5NTZkNjZkZWNjNDMyNjk3M2QxNWQ5Zjc2YzlhZDkyMDA2N2YwZTczYTQ0MmYyNzI0MzkgMHgzOTFjNWE3NjA1MWVjNTNmMGMwNTFhZGI1YjllYzQ5MTFmMDE1YTgxY2VkYzRlMmE4YTVhMGM4MjM2NzEyMjFmKSkpKSkpKShvcGVuaW5ncygocHJvb2YoKGxyKCgoMHg1ZDFlMzYxNWU1MzA4NzRkMmFkNTgwZDI1MGRiZWRjMDExYWViNWVlY2Y1MGQ4YmFmZTMwOWQ5N2VkMGE4YzE3IDB4OWViZjBkZWE1NTYwNzEwNDMyYWEwMmFhYmRiZDM3MDgxMjc0NWIyNDAwZDBiMGQ1NDM2NTA2OWNmMmM5YzYyOSkoMHgyMTY0NDNlMWM2YWQ0YmNiZDRiZGJkMjRlZTQyMDA5ZWNiNTUxY2UxM2Q2YThmMzUxNTllZjdiYTE5ODQ1MzFiIDB4Mzk4ZThiMzkzM2VmMjVlNjcwNjRkNTczYzVlMDg0YTkwMTEzMmQzM2Q4OTU3MzdkMzkxY2Y1YjI5Y2VjOTUwYykpKCgweDVhNWVhMjdmZGIxM2E0YzM2M2ZiM2JkMjMxZjNlOTMyMGFlZGIxN2Y1ZDgwZjkyMGY4NTUzZTJmOWU0ZDRhMzkgMHg1MDJkYmYwYjYxOTE0MWIwMTExOGVmN2M1NTlhNWNlNDhjODIyM2VmZjUwN2Q2MzQ0M2U3MjBjZmNiZmRjNTIzKSgweDE2ODFjNmUwOWZjNTJiYzA4ZjM5ZDdiYjg4NWFmZWQ4NjZkNzc2N2RmMWQ0OThlYTUwNjlkZGZjNzc5ZDM2MTcgMHhhN2FkMzE3MDE5NDQxZjYyMTBiMTk3NmFkMDlmNDZjZTFhYjlhYWUzNWQxM2EzMjU5OGY4NjQ2NDZkMDg4MTEyKSkoKDB4NTBjZTkzOTM1ZGE5MjZmYzQ4MWE5OGIzZDZkNjhiMjZjOTdhODcyZjY2Y2JmNGVhZjNiYjU5M2I1NDkxNWQwNSAweGM5NGM5ZGI2Y2QyMjM1ZTlhOTAyOWU1NjZlYWFjYjM0NDQ5OTg1MjFkMTZiYjdkOTNjOTIxMWJiMDkwNjkxMWEpKDB4MzQ3Nzc2NzlhNjY4OTcxNDMwZDczZGFhZGRhYjJlODdmZTc4YzY1OGI3YTQ0ODU2NDQ2YWJjMTk1NjQzZTIyOCAweGU2ZDJmN2ZiMzllM2M5ZGMyMjE5NmNlNzMzOTk5ZDhjN2Q5NTcxMGNmODQyMmJmNzgzMTJhZDIwOGFhYmUzMTEpKSgoMHhhMzNlZmY5MDc3YzQwMDQ0ZjQxNGNmMTM5NmFiMDVhYmQ5NjgxNzJmN2Q5ZGYyMTAzM2Q2Yzc0YTg3YWJmMzBlIDB4NzMyYzAwMWRhNGZhYzllMWRmNTAyMTZhZDEwZGE4YWE2YmQyYzg2NmNkMzZlZWQ4ODM5NWExMGQ2NzUwY2IxOCkoMHhiYjcxZGE4Nzg3MDc1ZWZhZmJjNWM2ZDZhYjNlYzdkMWU1NTRkNWM5ZDczZjNiYTJiODA2ZWQ2Mjk0ZjNjNzM4IDB4NWQzNzA3MTQxZWFjNWUwMDUxZTc5MmNiZWE4ZTA2NjU4NDNmMGYyN2FhYTI4OTY1YTk0OTFkYTc4OWUyODgwYykpKCgweGU1NjY5ZDIzZmVkNmU2M2UyZjQxOTJkNjA0N2MxNzg5ZGUxYTkxMjcyNmQ3YmZjMWE5NzFlZTdlY2RlYzgzMmEgMHg5ZTk3MzMwZmJjZDNiMDA3OTg3Y2ZhNWQ2OGU0YjUzY2IyY2M1YTg5MmNmYTFhNmJhODdhOTY1ZTliMzI1OTEyKSgweGRhYzE0MzQxN2M5MGY0NjczNGIxYWRjMWJiYWVlOWJlZjQwOGJiMDE5NWUwMGM4MDhiMDFhMmQ1NWZlMGY2MzcgMHgwOTUxNzllNDQ3MWY5YzM0ZTVjZWViYTMxMGJhNGZkM2Y1NDI2MTI0YTc1M2ZjYTAxNjdkZDY2YmJiYTk0NzI2KSkoKDB4ZmFhZWQ1ODAxY2NlZjg0YmUyYzg4YmExODY0ZWZiNGU0YTliOGRhYzVjMThiMmQ2YTYzMTkzZDAzYmZmMGEwMyAweGM5YTdhOWU1ZWYxODA1MDI4ZDA2YzE1OThjYzhkODZiMjU4MjdjNjMyZjdhMDc5ZTMwYjNjZjVmNzhiODBjMTEpKDB4MTQyYThiMDIxNDRlM2E2MDkyMjJhZDU4N2ZmZjQzODBlOGRiM2I5ZDFlZDdkYmVjMTYxZDk1NTNjMDUzMWQyNiAweDUyYWEyOGQwN2YwY2FhNzJlNWJhMzNhZjlmMzE0ZGQ1YjZhNGIwMTdkZGMzYjI4YTM2ZTQyY2M2ZDE0NjJlMzApKSgoMHgxMDE5OGZlMDRjMGNlZmJmODcyYzIzMmIwZTE0OTE4ODg2NDRjZDk3NDlkN2U0YTI5NzBiZDM3ZDEyNjBhYzE2IDB4MjgzNGRiYTQ1OWUxOGFhYmQ3ZDU1MmRlM2Q4ZmMzYzc0ZTJhOTQzZWI1ODFjZWE2MDg1YzQ5NGU2YmRmYWIxNCkoMHgzNjRmNWFmOTJjMzMxODUyM2NjOWViYWE0YTFmYWZmMWM2MGZlMzcwMjVjNzRjNTg1ZjE1ZTIzYTdhY2Q4YzMyIDB4Yzc1NTk5MTE3ZmU3NGFmYjgzOThlM2ExODZhNTQ2NzYzYTI2MWNlMGIwN2VmNjE5NGE2ZGM3MDFhNmI0YzQwNSkpKCgweGVhMTA5ZGY2NDU3MDMwNDcwZjFlMTY4YzQ4YWFhNmQwN2NiNzY3NWU2ZDg3NDllYzMyNmMwNWEyNjRjYTUwMGQgMHhmMmYxNDliZmY3ZjY0Zjg1OWNhOTFjMDFmMWVhZGNkNzRjYWYxZDExNmUxMjg2YjgyYTQzMjk5YTExYzgwNDI5KSgweGI1NWIwOGY0MDRhMWIxNDNjYzNkNjdkOTlmNzMwZjAxYzgxMzk2ZWU0NmZmMDViNDQ3YWQzY2JjN2Y0OWFjMjIgMHhlYjQyOTU5MTY0MmY5ZmVhZjhkNTQ2ZjlkMjAxZWM3Zjk5NGNlMGM0YjBkODkxNzFlOWY3NTdiYTViMzYyZjE5KSkoKDB4MGY4MjEwMDkzYzdkYjcyZDE1NjQ3NGUxNDVmYjhiYTBmNTJlNTEzYTE0MmFjNjM5MzMwMTk0OGJjZjBlNmEwMSAweDVhZjdiZWY0YWI1YTk2N2JiMzI4NTJmNmM5NTRkYTBhMjcyMDc3NzRhNTI5YjIwOTkzMjRjNzdjZmYxNWMxMWEpKDB4NTY5Njg2ZGJkOTE1ZmU5ZGU2YWZlNjY2YjBlYzBjZmE0MGIyNjJhODAzZWRkNzVlNmEyYTZiOTk3NWJkZTYyZiAweDkxNWJhYjBiOWY1YWQ3MmE5ZWU4ZjhkM2M0NTNiMDlmNTcxMDk5ZDFhZDA3NzAxMjkwZGZkMzA5MzJiZDI3MTcpKSgoMHgyNjIwYjg0ODJkNTZiYmY2NDJhZDQ4NWIzNDg5MTM2MzJlYmE4ZWNhOGJlZmIzYjBjOTU4ZTdlZDNjYjY3NzJjIDB4MWI1ZDBhYzlkMTgxNjNmYTRhOTc3ODdjNzA5MmIwOGY3OWNiMGViZjA4MTRiNTY0OTI0ODQxMmMxZjA0ODUyOSkoMHhkOGFkZWM0ZWIxODgzZjY3YjU3ZTJmODY3NmMyODE3NGY3YzNlMzQxOGYxMWRhZDc4NzdhNjMyMzNlYjE0MDJmIDB4NWEwMjhjOTNjOTY1NWQ0MGQzODdiODRhNTY1ZWY2Y2E1NzhmMTUzNDcwMzU2MzIyOWIyZDE0N2Q5ZDAzMjkxOSkpKCgweDJiNmY5NmE5NDIyZjc5MmI5MjBmODg2MjM4ZGE3ODg0MzIxZTM5ZmFlZTRlZGNjMzVjN2Q3YjZkMTEwMjk1MmIgMHhiNjdkMzk2YjkxYzJkY2VjNGNhYTBlMGZhOTkwYTUyNGQ4ZmQyNjA4NmIzNzVjNmQ2MjlhZDZiZWY3MDA1MjE2KSgweGM0YThkMzM1ZjhiZjk0NTNkNThlYTYxYjMyNWVkMjY0MTE5NDc3NWUwZGY1YTY0NmVjY2IwYzAxMjAxMzRhMzUgMHgyZDU3M2Q2ODEyMDA1MTFmNjI3ZjA0MWFkM2FlOGUwMjgxZGRjZjUyYzAyZjk0ZTM0NWM4MDQ4MDNiZmQ3NTExKSkoKDB4NDE4YzJmYjE5NTJkZjIxNzc3Nzg2MzA0Yzg2YzU4YWVhNWE5ZjRmOTU4OGM1ZDNlYTM2OTkwZjY0NzJhZDQxZCAweDJjMTlmMjZlM2I1NDAyNDI3NzFkNWI4NWM4M2JiYzUwYmZiMTY0MzdkNzcyODM4ODhkNWMxM2ZmNTFkMmU3MTUpKDB4MTFlOGEzYzA4MTU2NTZiNjIxOWVjYjAxMjgzNTI3YWIxM2VkZTE5NDk5ZWM0YmYzNWM3MDQxMDY3NjgyM2UyOCAweDYxMDIwZWI2ODRiZDA2NTE2OTRhYzQyZGY5OWUxZWEyNTljZmM4MWUwZmE4M2U3ZGRiYzI0ZjY3MDRhOTM5MjIpKSgoMHgwNDFhNGM2YzRmM2U1NDhkYzQ4MzAxZTA5ODE0NDQ1NzMwNjc0Yjk0MjVlMTIwODNkMzFjN2Y1NjUxZGY4MTFiIDB4Mjg0MDFjNmY3NmM2N2I1NDk1ZjhmM2NhODk1ODU4OThlOThjYjE1NTkyYWVmN2JmZTY0ZTJmMzczOTEyNmYxYykoMHg2OWMxZmU0NDUzMTdiYjY4NTM1ZWM4YTE1YjcwM2QwZjA1YTgxZmViMjkxMjIwNWY1YjMyODZjMTUyMGM1NTA5IDB4YzU4MTE3NjdjYmMyYmVhMmFjMDU5ZGRjZWFiN2UyNTY1NDhhYzM5YWFhZGM5OTY1OTZlZDdlNTBiMmY5MDEyMCkpKCgweDM5MGExOGQ3MDg5ZWI4MmJlNDdhZDg1MWU3YzFmYzAxZGExYzE0YzE1ZTc2YmM4NzE4OGUzMzNmYTRmMmU1MDcgMHg3YzdlMTM0OTA5NWM5NTVjN2JhZjY0ZjE1N2FiNDI2ZTc1ODdkNDI4NGFjODI3N2JmMTkzN2U4OTNiNzQyYzBiKSgweDU1NTI5ZDk2ZjQwMjY3MTAwN2Q2NjI1ZWIzZTZkN2E2NGI1OTNhYmM1MGQyYTc5ZTQ0NzRiZmI1ZmJiZDI5MTYgMHhkZTVlNGRhNGRhYjU5ODMyOWNiYjM4NjYzY2Q5YzZkNDliMDM0NTNjMWQxNzcxMjQ5ZjJkOWE4NWVjZWVkMTEzKSkoKDB4MmEwN2JjOGU2ZjkzN2RkYWNlNGU3NTQzNTgwMzY3ODc4NzlmOWU4NWNkZTA3YmU4MmUyOTUxODk5MWYzYTYzYSAweDgyNWFjYjI0ZWFjNmJjZGFhN2M4MDMxNjJiMTE2YTdhYTM1MmI5ZGQ1MDA0MWRiOTRmYjZjMzIwZWJhMmM1MDcpKDB4YzEwODE3ZWViZTcyNTQ4NWY2MDQ4ZjhkYTk4YmNkNTdiYThmNmRiMmQ3NDI5NjZlZTcwNjJhMWVmMGUyNmMyNyAweDJlNWI1ZGU2MzY4ZGJhOGRhNWFhYjRmZjMyNzUyNjFjMTZmYmQ5Y2Y2OTc3YzdiMTMxNjliMDRmMzNhM2Y5MjcpKSgoMHhkZmQ4N2U2NTlkYTY3NmY5MGZhNjE5ZThkMDQxM2IxM2VmOTJkNDY0ZjVmNjlmZDM5ZGIzM2VlMDBiNWIzNTI5IDB4NjExY2ZjMzdlY2ZlMTJmZTljZjhiODcyNjY4ZmU5MDQyOWQwZmI4MWE0ZjViM2JhMzJiNDNkZGUzNzYwODEwYikoMHg2ZGU4ZDM5NmMyNzBjZjQ0ODRkMDhmYzAzNzIzMjMwY2FlZmY0MjFiNjRjMTMyNDRjYzdkYjUzMTI3ODRkMzFiIDB4MjI2NTNmNmJhYWI1ODVmZDY3NTcyYzEzZjI1ZGZjNWE2MWM4Y2Y0OTA2NWY4MGQxNTA2YTU4Y2FiMWRhNWUxNikpKCgweDk2MDUwMmE2NDE2ZmQwMjc1NmY4ZmQyM2NkNzFiZjU5M2ZmYTgwNmJjYmI1MjA5OGU3Y2RlMTU5OTFiYzM1MDkgMHg1ZjdjZmMzNzMzMWUyYjk5NWI2Yzc3MDQ4NzE3Zjk2M2YzNWNiYzRjZDAyZTFhNWQ1YjMyN2Y5ZTYwYjk2NzAxKSgweGUzODU0NGY5ZWNmZDgyNDE4ZGU3NTAxMjliZGM5ZjFlNzJhNDFlMWU3NWQ2YzIyYWM1MTc3MDFkN2JjYzg2MjQgMHg0NzhhNzA3NTMxZWM4ZTQzNzA4ZjZlNGQzYTdhOGJjNWFlNWU0MjE3MDBlYzJiMTlmMjkzZGRmNzE1MTg3MjM0KSkpKSh6XzEgMHhjMWRkNzM5Mjk4N2QxNTRhZjg2YTg4MGMzYzlhOGJmMmNmZmM5ZDJjYWFhNDIwMzYzZmRkNWI1NWJhNWE1NDM1KSh6XzIgMHgyODZlZTAwMzZkNzg0NmM5NTE2NWQ3MjdmODAwNzkwMDRmOTcyZGQ5MmQxY2M3MzQ0MWRjZDM3MGZhM2FiMDAzKShkZWx0YSgweDY3ZjRlNzRlMzIyNzNjZmQ0YzU5YjIwZDM5MTljOTkyNDRkMzEwZDVmMzIxYjRlMTVhZDAwNGJmMzIwZDIyMTcgMHhlMDhiZDkyM2Y1ZDNiOTIyN2YyNGM5MWUyODkwNDRjYjQyZjkwNjZhMmRhNGZjNGYwYzM0ZWM5ZjEwN2ViMjA1KSkoc2coMHg2M2QxNmQxNjJiNzQ1MTc2ZTY0NjlhZmFiNTJmODAyMTFjOGJiMzJhZjQxMzI3MzFhZjU0OGM5YjZmMzA0NTBiIDB4NzZlOTA3NDNlNDMzNjc4MmZmMWNlMTYzZjNmMTFlMTlhZDZiZGZhZjU5NjM4NjI1MGNjZDdhOWQ5MDQ0MWYyYikpKSkoZXZhbHMoKChsKDB4YTFiMzgxMzdiMjc4Nzg3MzI4ODE1NDJlZjNjYzNmMGYyMjNmZWU5YmY4OGI0MDYxMmZkYmIzODliMzIwMjgxZCkpKHIoMHg4YTcyOGYxNzM1NDFlNDhjZTExYTBkZDJmYzk0NDgxOTY3MDc1ZDM5N2FhOTU1NzliYmY4NDc2NGUwMDA0MTFjKSkobygweGVhODZkOTZkMDU4MGJkY2M5ZWU0Nzk0MDU1OGRiYjQ3MzA0YmY3NmJiYjQ5ZTY3MzA1NzE4NGQyMDQ0ZjdjM2YpKSh6KDB4OTQ5YzdjMDBmZWRkYzVjZWVhNDk3YWQzODU4NWI5ZWRiOGJkZjJhNTBkMzIxMGRhNGRhM2NmMzkwZDI1ZDMwMSkpKHQoMHhkNGViY2QyMjdlOGRkNzMzNDEwYjQ4MzU5MTY5YThlMDE3YWNjNTIwYzFiMDNmYWQ0YTI2YjU5NDE5MThkODA1IDB4Mjk5MGQ3ODQ3ZmQ5ZWUwMTNjNWM4ODI1YWM0ZjQzMTQwNzkyODAxZDE1MDAyOWY0MmFhNmNmMjZjNTYyOTkyNCAweDNjMWQxNWFlODA1MzA2NDBjNDY3NzZjZmM5OWQzMmUwOTA5ODdlYTU4YmRmMjUxNzc3MTFjZTZkMjhmZGRhM2MgMHg2ZDAzMzZlYjQ1NGZlMjVkZjNhYzJmYTI1M2VhOTNjNjMyOGUwZTAzZmYzZWJkNTgyM2IwODIxZjM4MDNlYzExIDB4MmU3ZjQwZjYzYTJlYmY1YzQwY2YzNTA4ZjY2MDhiODk3OTcwNGJhNDg4NDNlNzMyMjU2ODU1MzRhOTY3ZWIyNykpKGYoMHg5YzE3NjBlZDZiNWRlYTY2MDIxOGIxYWIzM2NmNGUzYmIwZmYyMDFlMGI4OWRiZDkwNGMyYmQxZDc2NTdmYjA0KSkoc2lnbWExKDB4OTgwNzE3NGRiYzQxY2Y3MGZmODBmMGZkYmQwMGQzODM3MTBkZWJlNTdhMzk3MWY5YjE4ODVkNTBlYjQyN2EzNikpKHNpZ21hMigweDg4MjVjMTRhMGQzNTFhYmJmYjhkMGMyYjczMWFhNzk3OTJhOGE1Mjk4NGVkZWM1MWZhYzQ3YmU5OTZlZGIwMWIpKSkoKGwoMHg5MzFjNjU1ZDlhYTZkMDhhY2RhZjZkZmY3MzM1N2IxOWIzNGQ0MTkyZWUwYWM0ZjM3NjBlNThlNzgwZTlmZTA3KSkocigweDM1NGVkYmExZTNmNjI3NDEwYjlhZGQ4MDg0N2Q3OWI1NzIxMDM5ZjY5Y2E5NzEwM2ExNGVhMDVjNDljYzE4MjApKShvKDB4MmFmZjE3NGFhNWYwYTZhMjczNTk1OThlZDdhOTFkMDFhMmIzOWMyOTQ3OTM5YWQxNWYyODNmZGQ1ZjU2NWEyMykpKHooMHhmZjQ4YzBmMzMxZGUzYWE4MGRjOTcwYjgzYjZmYzRkZjNkMTA1NWUxODc0Yjc0M2M2YjI1MmViZGI2ZjQ5NTNmKSkodCgweGI4YzQ1NTllOWIxMDU1ZjA4MDZjYjg5OGM2NzQ3NjM3N2E1NTRiZGM4M2E3NWU1OTg2NmQ3ZTk5ZjgyNTgyMmIgMHhhYjFjYWU0YzQ2NzYzZTY5NTI4MThhN2M5ODNkODUwMmJhMWQ2ZDE3ZTI3ZDg0M2RkMDc5NWE1OWVhN2E2MDIwIDB4MTk3MjNjYTk5MzYwOWJjMDVlMWYwOWYzOTNkYTBkODNlYWYxODg1Nzg5MWY1Y2M1ZTViODFlNDliYzcxNzAwZCAweGQ2MDlmNzQzZWM0MDcwOTU3ZGQ4YjNlZTc2NGUzZGJiYjg3ZmQyN2IxYzdiNGQ4NjRhYWY1ZjVmMGQ2YWIyMWQgMHhhM2MyYjk2NGQ5MzQ3ODUzZDIwNWM0OTI2ZmI4YTk1MmJlNzMwNjVmMjI4MTg4ZTk4MDBjZjJhZGY2MzMzYzJlKSkoZigweGE2ZmNlMTk0N2Y4OWE4M2U2ZjJlODBhMWM0OTI1Zjc1ZjY2MTdkNTI5OTE0YzJkNTNkMGRjZTVhZTE4Yjc1MjcpKShzaWdtYTEoMHgxNjhkOWEwOGQzNDg1MjE0MTU2MzAxYzQzNDU3YzhiMmIxYWI3ZTA2MzM2ZjcyYjA4MjM0NDI3YzUzYmNlODMzKSkoc2lnbWEyKDB4ZjhlOTJmMjVkZDk1NjYxMDY1MTY3MDQyYWQ4MDFmMTJhNTkyMTI4ZjAyYjA3MjEwYzFhOWJmOTUyYTBhNjExZikpKSkpKSkpKSk="}, 
      data: {
        predicate: {
          fullOrNonceOrAccept: Full, 
          account: {
            balance:{checkOrIgnore: Ignore},
            nonce:{checkOrIgnore: Ignore},
            receiptChainHash:{checkOrIgnore: Ignore},
            publicKey:{checkOrIgnore: Ignore},
            delegate:{checkOrIgnore: Ignore},
            state:
              {elements: [{checkOrIgnore: Ignore},
              {checkOrIgnore: Ignore},
              {checkOrIgnore: Ignore},
              {checkOrIgnore: Ignore},
              {checkOrIgnore: Ignore},
              {checkOrIgnore: Ignore},
              {checkOrIgnore: Ignore},
             {checkOrIgnore: Ignore}]},
            rollupState:{checkOrIgnore: Ignore},
            provedState:{checkOrIgnore: Ignore}}}, 
        body: {
          depth: "0", 
          callData: "0x0000000000000000000000000000000000000000000000000000000000000000", 
          rollupEvents: [], 
          events: [], 
          delta: {sgn: PLUS, magnitude: "10000000000"}, 
          tokenId: "1", 
          update: {
            timing: {setOrKeep: Keep}, 
            tokenSymbol: {setOrKeep: Keep}, 
            snappUri: {setOrKeep: Keep}, 
            permissions: {
              setOrKeep: Set, 
              permissions:{
                stake:true,
                editState:Signature,
                send:Proof,
                receive:None,
                setDelegate:Signature,
                setPermissions:Signature,
                setVerificationKey:Proof,
                setSnappUri:Signature,
                editRollupState:Signature,
                setTokenSymbol:Signature}}, 
            verificationKey: {setOrKeep:Set, verificationKeyWithHash:{verificationKey: "AQEBAQECAQEADAEAAQEAEgECAQIBAcaMJ8BTrwJT4HZteN7ieVSTJ-NM9HEsabYRnVsLBWYyhXCV5LsroFJ-uiCqA65ryD9jc26-aAfkzltWTBOVzDsBOgG43gBAKpodINMAAwV9zM4mFxeSCTaOpLFU1eUrBBvU2JPcdickpmevVbDxykduBXOSl4cWnhjI1mrLfuELNgFDP50hhQ8FaqhZ_WKVQzXlVwAaxBdxjDLF4CXuy3cGE3Zq0QyXC-QAu82twqs68uJGlQgr9bKpIHPXMeFtqE85ARfz3Jcnk7W7ivRxLm1B5WeM2SqfbTDCkKvmh9eFL-MpepPZFGagylm1ztPyzxgswFz5fqMmou55frclj9H80REBQbfKnXGwgb3kfVzCF6xDZarqCbhaScDbJHOetfd0Lj3js9z7Cz2pcVEdu6grjE1nZgibwe-LClc9uPbhnoc2MgGuchX6G87gT2nqw6t-3rgoCjZTEN3rEs8zXtF6js7aIIQyjPwMnT8bPhJNBq-J9T3zy9mOHhUxoKRu6-oRh10LAU6i3oUzYIHOYS6K5y09RI9_4E8-DKAaefXBrrdf80MSvLhhj7zjAqrdeAKu5vkkwhmBuFaNFDEUsi4Nj4oVOhwBxeMlQb7X0mokr-yK5HYhZ9oon1reb5uIws5U8fsBBBpZIkiEdbBvzBseQER0bdot8IrCr4rT85x3f7ARuQ3oEAGh4xpXkFBf0-7l53PnSLGVDpFN-ZEYs_AjBgZN2aLjBzFn0-aQJhE_iiMp39-90QUENvJrWGcXET1qJZbfi5A0ASjvLeea-lyXSMQd6uAEztuwbRQOoO0_ew1nEjeQudYAESZQ_8LCh7gteG2uoizWvNs7OEtonxrlgvu6nRmNtS4BpsQqViblkB-Rk7JeRnM3wKb2oub1qLbO2LZmiJapwiKjl1XSECKedtgGfOW6f5x0CHsEhYEk8jNB148RntOeKwHR96m_FUMy3q2vT63_mGlueMuhlNbzA2Oj-LLm5wFBOEycuRlBfccVFhMrQRbFTSBXc2OByTks8DFZleeURmQeAaXN6IkCO8EhhpzM-HgAvDlmMfgS50dirjo9OFkF7zYWAlRpy6Vg-_kjKzIGVlo0T-E8Og6KZHcrJ66pR4iHnyEBH6c3Bpy9WoE4k_H_0b-Vg2ny1tko1hZir3Hzc5kJkDz7_qhyWnCyoaSsDxIJqO3BNTPq5r-DQbK1XWglujMyFQHwyRDJU_0SftlZRmT3I78LFJpR9P-QJVkQr6MUgISZIFnybEJ2TZ-lrkO0Kgnd0mRVCx66ljTDZBsqBqHI9kEiATWbHpDxG1sRNchqOaOA6-iqNMba9kTGtU516v3UKQ08auL8rjJnuJYxnYT2mpLQ-cfg90n8EYsv2ZkQRtmUZQQBguW25wI_Dp7MlRTXCaE2U3xdXYNl4LcQRINkpGX6bxcWyJw4ZrwJaSPJDJrloceUrhTfbUcGTIaVZq-lizL5DAHHPT89u5CkpkuWgCDIb5GUs0w2pvjskdIdzwuXI2qaKHiXNZx3ACRTX21BQXlbp5OFLYZUp6l_F7uX_x7XrmIK", hash: "2473183685549273309420206841833610662200156533369253556706124767999189057958"}}, 
            delegate: {setOrKeep: Keep}, 
            appState: [
          {setOrKeep: Keep} ,
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep}]}, 
          pk: "B62qpNvMKvv49GZy2vD5TpyK1n3TzJFR1BVrbCXoSPDDuy9Z7NSxAzo"}}}], 
    snappFeePayer: {
      authorization: "7mXG6tb8hegfutaTbDuLcdLRiw8uxvig6aetxL9eFoKAeMJXqvwhLC9id3kEEqtBP5CHJFzCzPv8ce7iPGq5y8SwQn9Sd5UW", 
      data: {
        predicate: "0", 
        body: {
          depth: "0", 
          callData: "0x0000000000000000000000000000000000000000000000000000000000000000", 
          rollupEvents:[], 
          events: [], 
          fee: "10000000000", 
          update: {
            timing: {setOrKeep: Keep}, 
            tokenSymbol: {setOrKeep: Keep}, 
            snappUri: {setOrKeep: Keep}, 
            permissions: {setOrKeep: Keep}, 
            verificationKey: {setOrKeep: Keep}, 
            delegate: {setOrKeep: Keep}, 
            appState: [
          {setOrKeep: Keep} ,
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep},
          {setOrKeep: Keep}]}, 
          pk: "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"}}}})
}
    |}
in*)

module T = Transaction_snark.Make (struct
  let constraint_constants = constraint_constants

  let proof_level = proof_level
end)

let generate_snapp_txn (keypair : Signature_lib.Keypair.t) (ledger : Ledger.t) =
  let open Deferred.Let_syntax in
  let receiver =
    Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
  in
  let spec =
    { Transaction_logic.For_tests.Transaction_spec.sender =
        (keypair, Account.Nonce.zero)
    ; fee = Currency.Fee.of_int 10000000000 (*1 Mina*)
    ; receiver
    ; amount = Currency.Amount.of_int 10000000000 (*10 Mina*)
    }
  in
  let%bind parties =
    Transaction_snark.For_tests.create_trivial_predicate_snapp
      ~constraint_constants spec ledger
  in
  Core.printf "Snapp transaction: %s\n%!"
    (Parties.to_yojson parties |> Yojson.Safe.to_string) ;
  List.iter (Ledger.to_list ledger) ~f:(fun acc ->
      Core.printf "Account: %s\n%!"
        (Account.to_yojson acc |> Yojson.Safe.to_string)) ;
  (*Array.iter init_ledger ~f:(fun (kp, amount) ->
      let _tag, account, loc =
        L.get_or_create l
          (Account_id.create
             (Public_key.compress kp.public_key)
             Token_id.default)
        |> Or_error.ok_exn
      in
      L.set l loc { account with balance = Currency.Balance.of_int amount }) ;*)
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:Genesis_constants.compiled.protocol
  in
  let state_body =
    let compile_time_genesis =
      (*not using Precomputed_values.for_unit_test because of dependency cycle*)
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
        ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
        ~constraint_constants ~consensus_constants
    in
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  let witnesses =
    Transaction_snark.parties_witnesses_exn ~constraint_constants ~state_body
      ~fee_excess:Currency.Amount.Signed.zero
      ~pending_coinbase_init_stack:Pending_coinbase.Stack.empty (`Ledger ledger)
      [ parties ]
  in
  let open Async.Deferred.Let_syntax in
  let%map _ =
    Async.Deferred.List.fold ~init:((), ()) (List.rev witnesses)
      ~f:(fun _ (witness, spec, statement, _snapp_stmts) ->
        let%map _ = T.of_parties_segment_exn ~statement ~witness ~spec in
        ((), ()))
  in
  ()

(*;
  let a  = graphql_snapp_command parties
  in
  Core.printf "%s" a*)

let main keyfile config_file () =
  let open Deferred.Let_syntax in
  let%bind keypair =
    Secrets.Keypair.Terminal_stdin.read_exn ~should_prompt_user:false
      ~which:"payment keypair" keyfile
  in
  let%bind ledger =
    let%map config_json = Genesis_ledger_helper.load_config_json config_file in
    let runtime_config =
      Or_error.ok_exn config_json
      |> Runtime_config.of_yojson |> Result.ok_or_failwith
    in
    let accounts =
      let config = Option.value_exn runtime_config.Runtime_config.ledger in
      match config.base with
      | Accounts accounts ->
          lazy (Genesis_ledger_helper.Accounts.to_full accounts)
      | _ ->
          failwith "invlaid genesis ledger- pass all the accounts"
    in
    let packed =
      Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
        ~depth:constraint_constants.ledger_depth accounts
    in
    Lazy.force (Genesis_ledger.Packed.t packed)
  in
  generate_snapp_txn keypair ledger

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Generate a trivial snapp transaction for testing"
        (let%map keyfile =
           Param.flag "--fee-payer-key"
             ~doc:
               "KEYFILE Private key file for the fee payer of the transaction"
             Param.(required string)
         and config_file =
           Param.flag "--config-file" ~aliases:[ "config-file" ]
             ~doc:
               "PATH path to a configuration file consisting the genesis ledger"
             Param.(required string)
         in
         main keyfile config_file)))
