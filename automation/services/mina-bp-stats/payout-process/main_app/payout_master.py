from payouts_calculate import main as calculate_main
from payouts_calculate import read_staking_json_list
from payouts_calculate import get_last_processed_epoch_from_audit as get_c_audit

from payouts_validate import main as v_main
from payouts_validate import get_last_processed_epoch_from_audit as get_v_audit
from payouts_validate import determine_slot_range_for_validation
import sys

if __name__ == "__main__":
    c_epoch = get_c_audit()
    v_epoch = get_v_audit('validation')
    last_epoch = 0
    if c_epoch > v_epoch:
        last_epoch = v_epoch
    else:
        last_epoch = c_epoch
    
    total_epoch_to_cover = 8
    if last_epoch>0:
        total_epoch_to_cover = last_epoch+1
    else:
        staking_ledger_available = read_staking_json_list()
        end=0
        result = 0
        for count in range(0, total_epoch_to_cover):
            calculate_main(count, False)
            result = v_main(count, False)
    sys.exit(total_epoch_to_cover)
