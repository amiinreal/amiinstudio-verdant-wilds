import pathlib,sys,zipfile
source=pathlib.Path(sys.argv[1]).resolve()
target=pathlib.Path(sys.argv[2]).resolve()
if target.is_relative_to(source):raise SystemExit("Archive must be outside its source")
with zipfile.ZipFile(target,"w",zipfile.ZIP_DEFLATED,compresslevel=5) as output:
    for file in sorted(source.rglob("*")):
        if file.is_file() and file.suffix not in (".pdb",):output.write(file,file.relative_to(source).as_posix())
print(target.name,target.stat().st_size,"bytes")
