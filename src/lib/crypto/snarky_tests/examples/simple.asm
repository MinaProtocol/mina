row0.pub.Generic<1,0,0,0,0>
.l1 -> row4.l1

row1.pub.Generic<1,0,0,0,0>
.l1 -> row2.l1

row2.Generic<-1,0,0,1,0><-1,0,0,1,0>
.l1 -> row4.r1, .r1 -> row1.l1, .l2 -> row0.l1
.r2 -> row2.l2

row3.Generic<-1,0,0,1,0><-1,0,0,1,0>
.l1 -> row4.r2, .r1 -> row3.l1, .l2 -> row4.l2
.r2 -> row3.l2

row4.Generic<0,0,1,-1,0><0,0,1,-1,0>
.l1 -> row2.r2, .r1 -> row2.r1, .o1 -> row5.l1
.l2 -> row3.r2, .r2 -> row3.r1, .o2 -> row4.o1

row5.Generic<1,0,0,0,-1>
.l1 -> row4.o2
