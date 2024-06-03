# Fix missing debs

Small utility to fix debian packages hash mismatch.

## Usage 

In current form app requires all files (*.deb, Release, Packages) to be dumped into single folder. App is backing up Release and Packages files and not touching *.debs.

### Commands

- print-checksums - prints out checksums of debian package or Packages file. Example:
```
python fix_missing_debs.py print-checksums --path ./bullseye --regex .*deb
```

- update-packages - updates Package file based on debian residing in folder. Example:

```
python fix_missing_debs.py update-packages --path ./bullseye --regex .*deb --arch amd64 --component beta
```

- update-release - updates Release and Packages files based on selected debians
```
update-releases --path ./bullseye --regex .*deb --arch amd64 --component beta
```


### Future work

It is still required to download and upload packages to aws based debian repo