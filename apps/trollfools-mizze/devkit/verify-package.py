import hashlib,json,pathlib,plistlib,struct,sys,zipfile
app=pathlib.Path(sys.argv[1]);identity=json.loads(pathlib.Path('build-menu/MizzePayload.json').read_text())
tools=['chown','cp','cp-15','ct_bypass','insert_dylib','mkdir','mv','mv-15','rm','install_name_tool','optool','ldid']
libraries=['libcrypto.3.dylib','libintl.8.dylib','libiosexec.1.dylib','libxar.1.dylib']
for name in ['TrollFools',*tools,*libraries]:
    data=(app/name).read_bytes();assert len(data)>100 and data[:4] in [b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe'],name
assert hashlib.sha256((app/'MizzePayload.zip').read_bytes()).hexdigest()==identity['zipSha256']
assert plistlib.loads((app/'Info.plist').read_bytes())['MizzePayloadSHA256']==identity['zipSha256']
with zipfile.ZipFile(app/'MizzePayload.zip') as z:
    assert z.namelist()==['Mizze.dylib']
    assert hashlib.sha256(z.read('Mizze.dylib')).hexdigest()==identity['dylibSha256']
report={'payload':identity,'allInjectorToolsPresent':True,'helpersChecked':len(tools),'helperLibrariesChecked':len(libraries),'payloadHashMatchesSignedPlist':True,'deviceTested':False}
pathlib.Path('build/package-verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))

known=json.loads(pathlib.Path('devkit/upstream-tools-sha256.json').read_text())
for name,digest in known['files'].items():
    assert hashlib.sha256((app/name).read_bytes()).hexdigest()==digest,'Packaged helper was modified: '+name
report['originalHelperHashesPreserved']=True
report['originalHelpersVerified']=len(known['files'])
pathlib.Path('build/package-verification.json').write_text(json.dumps(report,indent=2))
print('Original helper signatures/bytes preserved for all '+str(len(known['files']))+' assets')
