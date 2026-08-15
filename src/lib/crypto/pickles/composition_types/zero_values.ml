type ('chal, 'fp) single = { challenge : 'chal; scalar : 'fp }

type ('chal, 'chal_var, 'fp, 'fp_var) t =
  { value : ('chal, 'fp) single; var : ('chal_var, 'fp_var) single }
