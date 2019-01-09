type true_ = unit

type false_ = unit

type _ t = True : true_ t | False : false_ t

type true_t = true_ t

type false_t = false_ t
