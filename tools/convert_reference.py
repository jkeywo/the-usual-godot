"""One-time conversion of the frozen RON baseline; not a runtime dependency."""
import json, re, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Ron:
 def __init__(self,text):
  token=re.compile(r'\s+|//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z_0-9]*|[()\[\]{},:]',re.S)
  self.t=[]; pos=0
  for m in token.finditer(text):
   if text[pos:m.start()].strip(): raise ValueError(text[pos:m.start()])
   s=m.group();pos=m.end()
   if not s.isspace() and not s.startswith('//') and not s.startswith('/*'): self.t.append(s)
  self.i=0
 def take(self):
  s=self.t[self.i];self.i+=1;return s
 def peek(self): return self.t[self.i] if self.i<len(self.t) else ''
 def value(self):
  s=self.take()
  if s.startswith('"'): return json.loads(s)
  if re.fullmatch(r'-?\d+',s): return int(s)
  if s in ('true','false','None'): return {'true':True,'false':False,'None':None}[s]
  if s in ('[','(','{'):
   end={'[':']','(':')','{':'}'}[s]; items=[]; fields={}; pairs=[]; mapping=False
   while self.peek()!=end:
    if self.peek()==',': self.take();continue
    v=self.value()
    if self.peek()==':':
     mapping=True;self.take();val=self.value();pairs.append([v,val])
     if isinstance(v,(str,int)): fields[v]=val
    else: items.append(v)
   self.take()
   if mapping: return fields if len(fields)==len(pairs) else {'$map':pairs}
   if s=='(' and len(items)==1:return items[0]
   return items if items or s!='(' else {}
  if self.peek()=='(':
   arg=self.value()
   if s=='Some':return arg
   return {'kind':s,'value':arg}
  return s

def gd(v):
 if v is None:return 'null'
 if isinstance(v,bool):return str(v).lower()
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 if isinstance(v,int):return str(v) if v<=9223372036854775807 else json.dumps(str(v))
 if isinstance(v,list):return '['+', '.join(map(gd,v))+']'
 return '{'+', '.join(gd(k)+': '+gd(val) for k,val in v.items())+'}'

def normalize(v):
 if isinstance(v,int) and (v>9223372036854775807 or v< -9223372036854775808): return str(v)
 if isinstance(v,list):return [normalize(i) for i in v]
 if isinstance(v,dict):return {str(k):(str(x) if k=='keyed_marker' else normalize(x)) for k,x in v.items()}
 return v

if __name__=='__main__':
 manifest=[]; hashes={}
 for p in sorted((ROOT/'.reference/rust/assets/content').rglob('*.ron')):
  rel=p.relative_to(ROOT/'.reference/rust/assets/content'); target=ROOT/'content'/rel.with_suffix('.tres'); target.parent.mkdir(parents=True,exist_ok=True)
  parsed=Ron(p.read_text(encoding='utf-8-sig')).value()
  target.write_text('[gd_resource type="Resource" script_class="VillageAsset" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://sim/village_asset.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\ndomain = '+gd(rel.parts[0])+'\ndata = '+gd(parsed)+'\n',encoding='utf-8')
  manifest.append('res://content/'+rel.with_suffix('.tres').as_posix());hashes[rel.as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
 (ROOT/'content/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (ROOT/'tests/content_sources.json').write_text(json.dumps(hashes,indent=2)+'\n')
 for p in (ROOT/'tests/reference').glob('*.ron'):
  p.with_suffix('.json').write_text(json.dumps(normalize(Ron(p.read_text()).value()),indent=2)+'\n')
 print('Converted',len(manifest),'authored assets')
