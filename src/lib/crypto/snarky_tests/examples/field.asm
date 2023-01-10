row0.pub.Generic<1,0,0,0,0>
.l1 -> row2.l1

row1.Generic<1,0,0,0,-2><1,0,-1,0,1>
.l1 -> row1.o2
.l2 -> row0.l1, .o2 -> row1.l1

row2.Generic<1,0,-1,0,1><0,0,0,1,-1>
.l1 -> row2.l2, .o1 -> row3.l1
.l2 -> row1.l2

row3.Generic<0,0,0,1,-1>
.l1 -> row2.o1
