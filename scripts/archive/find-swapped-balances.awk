# find-swapped-balances.awk -- find swapped combined fee transfer balances in replayer logs

(match($0,"Starting")) { LAST_STARTING = $0 }
(match($0,"Applying combined")) { print "---------------"; print LAST_STARTING ; print $0 }
(match($0,"Claimed")) { print $0 }
