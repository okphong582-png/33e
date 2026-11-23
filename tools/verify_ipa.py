from pathlib import Path
import zipfile,plistlib,hashlib,json,subprocess,sys,tempfile
p=Path(sys.argv[1]);out=Path(sys.argv[2]);raw=p.read_bytes()
with zipfile.ZipFile(p) as z:
 assert z.testzip() is None
 roots={n.split('/')[1] for n in z.namelist() if n.startswith('Payload/') and '.app/' in n}
 assert roots=={'Mizze.app'},roots
 prefix='Payload/Mizze.app/'
 info=plistlib.loads(z.read(prefix+'Info.plist'))
 assert info['CFBundleExecutable']=='Mizze'
 assert info['CFBundleDisplayName']=='Mizze Kernel'
 assert info['CFBundleIdentifier']=='vn.mizze.kernel.ffvn'
 assert info['UIUserInterfaceStyle']=='Dark'
 assert info['CFBundleVersion']=='20261123.3'
 assert info['CFBundleShortVersionString']=='1.4.2'
 gif_hash=hashlib.sha256(z.read(prefix+'Mizze-Antiban-Eye-Slow.gif')).hexdigest()
 assert gif_hash=='1d98523ecd1ae8a9b45a7d528361caadd3bf56102e8906593b3f9f76eb381c0c'
 data=z.read(prefix+'Mizze')
 assert b'-----BEGIN PRIVATE KEY-----' not in data
 assert b'-----BEGIN RSA PRIVATE KEY-----' not in data
 assert not any('APIClient' in n or n.endswith('.lnk') for n in z.namelist())
 with tempfile.TemporaryDirectory() as t:
  binary=Path(t)/'Mizze';binary.write_bytes(data)
  arches=subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip()
  assert 'arm64' in arches
  for architecture in arches.split():
   thin=Path(t)/('Mizze-'+architecture)
   subprocess.run(['lipo',str(binary),'-thin',architecture,'-output',str(thin)],check=True)
   ent=plistlib.loads(subprocess.check_output(['ldid','-e',str(thin)]))
   assert ent.get('application-identifier')=='TROLLTROLL.vn.mizze.kernel.ffvn'
   assert ent.get('com.apple.developer.team-identifier')=='TROLLTROLL'
   assert ent.get('keychain-access-groups',[])[0]==ent['application-identifier']
 result={'ipa':p.name,'ipaBytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'binarySha256':hashlib.sha256(data).hexdigest(),'bundle':info['CFBundleIdentifier'],'version':info['CFBundleVersion'],'gifSha256':gif_hash,'architectures':arches,'zipCrcValid':True,'entitlementsParsed':True,'privateKeyMarkersAbsent':True,'physicalIphoneTested':False,'gameplayFpsMeasured':False}
out.write_text(json.dumps(result,indent=2))
print(json.dumps(result))
