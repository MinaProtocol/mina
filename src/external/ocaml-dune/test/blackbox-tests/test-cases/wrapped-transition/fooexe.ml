Mylib.Bar.run ();;
Mylib.Foo.run ();;
Bar.run ();;
Foo.run ();;

module Y : Mylib.Intf_only.S = struct end
module X : Intf_only.S = struct end
