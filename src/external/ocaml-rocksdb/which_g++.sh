for version in 5.2 4.9 4.8;
do
    g++-$version --version > /dev/null 2> /dev/null
    if [[ $? -eq 0 ]];
    then echo g++-$version ; exit 0
    fi

done
