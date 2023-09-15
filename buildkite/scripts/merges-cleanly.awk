BEGIN {
    current_file = "";
    filename_printed = 0;
    display = 0;
    status = 0;
}

/^  (base|our|their|result)/ {
    if ( $4 != current_file ) {
        current_file = $4;
        filename_printed = 0;
    }
}

/^[\+\-]<<</ {
    display = 1;
    status = 1;
    if ( filename_printed == 0 ) {
        print "File: " current_file;
        filename_printed = 1;
    }
}

/^[\+\-]>>>/ {
    display = 0;
    print;
    print "";
}

/^[\+\- ]/ {
    if ( display == 1 ) {
        print;
    }
}

END {
    exit status;
}
