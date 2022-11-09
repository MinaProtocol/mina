row0.pub.Generic<1,0,0,0,0>
.l1 -> row3.l1

row1.Generic<-1,0,0,1,0><-1,0,0,1,0>
.l1 -> row2.l1, .r1 -> row5.l2
.l2 -> row3.l2, .r2 -> row1.l2

row2.Generic<2,4,-1,0,0><-1,0,0,1,0>
.l1 -> row1.r1, .r1 -> row6.l1, .o1 -> row3.r2
.l2 -> row2.r1, .r2 -> row2.l2

row3.Generic<-1,0,-1,0,7><1,1,-1,0,0>
.l1 -> row0.l1, .o1 -> row4.o2
.l2 -> row4.l1, .r2 -> row2.o1, .o2 -> row4.l2

row4.Generic<-1,0,-1,0,1><1,0,-1,0,0>
.l1 -> row1.r2, .o1 -> row5.l1
.l2 -> row3.o2, .o2 -> row3.o1

row5.Generic<0,0,1,-1,0><-1,0,-1,0,1>
.l1 -> row4.o1, .r1 -> row5.o2, .o1 -> row6.l2
.l2 -> row1.l1, .o2 -> row5.r1

row6.Generic<0,0,1,-1,0><-1,0,-1,0,1>
.l1 -> row7.l1, .r1 -> row6.o2
.l2 -> row5.o1, .o2 -> row6.r1

row7.Generic<1,0,0,0,-1>
.l1 -> row2.r2
