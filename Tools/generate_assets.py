"""Original Egg Dash models. Run: blender -b --python Tools/generate_assets.py -- Godot/assets"""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
out=Path(sys.argv[sys.argv.index('--')+1]).resolve();out.mkdir(parents=True,exist_ok=True)
random.seed(12)
materials={}
def mat(hex):
 if hex in materials:return materials[hex]
 m=bpy.data.materials.new(hex);m.diffuse_color=tuple(int(hex[i:i+2],16)/255 for i in (0,2,4))+(1,);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=tuple(v**2.2 for v in m.diffuse_color[:3])+(1,);bs.inputs['Roughness'].default_value=.52
 materials[hex]=m;return m
def xyz(v):return (v[0],-v[2],v[1])
def empty(name,p=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=xyz(p);return o
def cube(name,p,s,c,bevel=.06,parent=None):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.name=name;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Soft plastic edge','BEVEL');mod.width=min(bevel,min(s)*.3);mod.segments=3
  bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.materials.append(mat(c));o.parent=parent;o.location=xyz(p);return o
def sphere(name,p,s,c,parent=None,segments=20,rings=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings);o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True
 o.data.materials.append(mat(c));o.parent=parent;o.location=xyz(p);return o
def cyl(name,p,r,h,c,parent=None,vertices=20,r2=None):
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=h);o=bpy.context.object;o.name=name
 bevel=o.modifiers.new('Rounded rim','BEVEL');bevel.width=.04;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name)
 o.data.materials.append(mat(c));o.parent=parent;o.location=xyz(p);return o
def rod(name,a,b,r,c,parent=None):
 av=Vector(xyz(a));bv=Vector(xyz(b));d=bv-av
 o=cyl(name,(0,0,0),r,d.length,c,parent,12);o.location=(av+bv)/2;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def begin():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def export(name):
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
begin();cube('Unit',(0,0,0),(1,1,1),'ffffff',.045);export('soft_box')
begin()
cube('Hoodie',(0,1.7,0),(1.18,1.16,.72),'ef493c',.11)
cube('Hood hem',(0,1.17,0),(1.18,.17,.74),'cd342d',.04)
cube('Hood',(0,2.13,.1),(.85,.35,.75),'dc3c31',.13)
cube('Pocket',(0,1.5,-.385),(.65,.33,.08),'ff6751',.06)
rod('Pocket seam',(-.22,1.55,-.44),(.22,1.55,-.44),.012,'d73d30')
cyl('Neck',(0,2.32,0),.26,.24,'ffd357')
cube('Head',(0,2.72,0),(.88,.86,.84),'ffdb59',.16)
for x in [-.2,.2]:
 sphere('Eye',(x,2.77,-.417),(.048,.07,.022),'253343')
 sphere('Eye glint',(x-.012,2.795,-.437),(.013,.018,.008),'ffffff')
# smile curve as tiny connected rods
for i in range(6):
 a=-.17+i*.34/6;b=-.17+(i+1)*.34/6
 rod('Smile',(a,2.52+.10*(a/.17)**2,-.429),(b,2.52+.10*(b/.17)**2,-.429),.016,'253343')
cube('Cap',(0,3.1,.025),(.94,.24,.88),'273247',.13)
cube('Brim',(0,3.02,-.37),(.98,.10,.65),'273247',.045)
cube('Cap badge',(0,3.14,-.43),(.15,.10,.015),'ffd151',.025)
cube('Backpack',(0,1.75,.53),(.8,.9,.4),'22466f',.14)
cube('Backpack pocket',(0,1.58,.77),(.58,.35,.12),'346493',.07)
cube('Backpack clasp',(0,1.85,.77),(.18,.16,.045),'ffd151',.025)
for x in [-.4,.4]:cube('Strap',(x,1.86,.40),(.12,.9,.1),'15324f',.03)
for side,x in [('Left',-.88),('Right',.88)]:
 pivot=empty(side+'Arm',(x,2.17,0))
 cube('Sleeve',(0,-.35,0),(.53,.72,.67),'ef493c',.08,pivot)
 cube('Cuff',(0,-.69,0),(.54,.14,.68),'ce3b30',.03,pivot)
 cube('Hand',(0,-.94,0),(.52,.42,.64),'ffdb59',.085,pivot)
for side,x in [('Left',-.32),('Right',.32)]:
 pivot=empty(side+'Leg',(x,1.15,0))
 cube('Jeans',(0,-.42,0),(.58,.82,.64),'347bd0',.07,pivot)
 cube('Knee seam',(0,-.55,-.33),(.4,.02,.02),'629fea',.008,pivot)
 cube('Shoe',(0,-1.0,-.10),(.61,.32,.82),'f3f6ff',.07,pivot)
 cube('Sole',(0,-1.14,-.10),(.62,.08,.84),'c7d6e6',.02,pivot)
 cube('Shoe trim',(0,-.94,-.52),(.40,.1,.02),'263f61',.01,pivot)
export('avatar')
begin()
cube('Body',(0,1.1,.0),(1.65,1.1,2.3),'ed852c',.25)
cube('Chest',(0,1.22,-.85),(1.2,.95,.5),'fff0d3',.18)
cube('Head',(0,1.95,-1.05),(1.9,1.4,1.45),'f39733',.25)
for x in [-.55,.55]:
 ear=cyl('Ear',(x,2.92,-.9),.48,.95,'e88329',vertices=3,r2=0);ear.rotation_euler.z=math.pi/2
 cyl('Inner ear',(x,2.90,-.92),.25,.57,'ffd8b5',vertices=3,r2=0)
 cube('Cream cheek',(x*.75,1.7,-1.70),(.85,.65,.35),'fff0d3',.20)
 sphere('Eye',(x*.9,2.12,-1.77),(.11,.15,.04),'263244')
 sphere('Glint',(x*.9-.025,2.16,-1.806),(.03,.035,.015),'ffffff')
 brow=cube('Brow',(x*.9,2.35,-1.76),(.31,.07,.06),'7c3f23',.02);brow.rotation_euler.y=0;brow.rotation_euler.z=(.18 if x<0 else -.18)
sphere('Nose',(0,1.8,-1.98),(.23,.16,.16),'273244')
for x in [-.55,.55]:
 for z in [-.65,.72]:
  cube('Leg',(x,.5,z),(.45,.8,.53),'c96a25',.1)
  cube('Paw',(x,.18,z-.12),(.49,.3,.72),'493e38',.09)
rod('Tail',(0,1,.9),(0,1.7,2.2),.37,'ee8d33')
rod('Tail tip',(0,1.7,2.2),(0,1.95,2.65),.33,'fff0d3')
export('fox')
begin()
cube('Body',(0,.42,0),(.85,.70,1.0),'56d2e9',.18)
cube('Head',(0,.95,-.25),(1.05,.88,.85),'66def0',.21)
for x in [-.28,.28]:
 cyl('Horn',(x,1.55,-.1),.13,.40,'ffdd89',vertices=8,r2=.02)
 sphere('Eye',(x,1.04,-.67),(.065,.10,.035),'243c53')
 sphere('Shine',(x-.018,1.08,-.697),(.02,.027,.012),'ffffff')
 sphere('Blush',(x*1.25,.87,-.65),(.10,.045,.02),'ffb4b3')
 for z in [-.25,.32]:cube('Foot',(x,.11,z),(.25,.22,.30),'38b8d5',.07)
 wing=cube('Wing',(x*2.3,.70,.15),(.48,.13,.5),'c9f7ff',.06);wing.rotation_euler.y=(.4 if x>0 else -.4)
rod('Tail',(0,.4,.4),(0,.65,.9),.14,'56d2e9')
cyl('Tail fin',(0,.8,.91),.16,.25,'ffdd89',vertices=4,r2=0)
export('dragon')
begin()
cube('Body',(0,.4,0),(.9,.8,.9),'a5b5ca',.18)
for x in [-.28,.28]:
 cyl('Ear',(x,.94,0),.22,.4,'a5b5ca',vertices=3,r2=0)
 sphere('Eye',(x,.52,-.46),(.065,.09,.025),'243c53')
 sphere('Shine',(x-.015,.55,-.48),(.018,.024,.01),'ffffff')
 for z in [-.2,.2]:cube('Paw',(x,.1,z),(.25,.2,.28),'e4eaf4',.05)
sphere('Nose',(0,.36,-.48),(.07,.045,.035),'f6a4b8')
rod('Tail',(.3,.3,.3),(.6,.8,.5),.1,'a5b5ca')
export('cat')
begin()
cyl('Trunk',(0,1.4,0),.38,2.8,'956a43',vertices=8)
for a in [-1,1]:rod('Branch',(0,1.6,0),(a*.7,2.5,.1),.18,'956a43')
for pos,sz,c in [((0,3,0),(2.9,2.3,2.7),'42994b'),((-.65,3.9,0),(2.3,1.65,2.1),'62b34e'),((.7,3.4,.2),(2.3,1.8,2.6),'71be51'),((.1,4.7,0),(1.9,.8,1.8),'82c957')]:cube('Foliage',pos,sz,c,.28)
export('tree')
begin()
# Shape a pear-like egg in mesh space, then position speckles on its surface.
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20);egg=bpy.context.object;egg.name='Egg shell'
for v in egg.data.vertices:
 z=v.co.z; factor=.54*(1-.18*z);v.co.x*=factor;v.co.y*=factor;v.co.z*=.73
for f in egg.data.polygons:f.use_smooth=True
egg.data.materials.append(mat('b5eff9'))
for i in range(36):
 theta=random.uniform(0,math.tau);z=random.uniform(-.52,.58);normz=z/.73
 r=math.sqrt(max(0,1-normz**2))*.54*(1-.18*normz)
 p=(r*math.cos(theta),r*math.sin(theta),z)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6);o=bpy.context.object;o.name='Shell spot';o.location=p
 normal=Vector((p[0]/.54**2,p[1]/.54**2,p[2]/.73**2)).normalized();o.rotation_euler=normal.to_track_quat('Z','Y').to_euler();radius=random.uniform(.035,.08);o.scale=(radius,radius,.009);o.data.materials.append(mat('64bcd9'))
export('egg')
begin()
# Nest ring, layered straw, interior soft bedding.
cyl('Bedding',(0,.13,0),1.03,.25,'b88a4b',vertices=24)
for j in range(3):
 for i in range(18):
  a=i*math.tau/18+j*.11;b=a+.50;r=1.02-j*.06
  rod('Woven straw',(math.cos(a)*r,.17+j*.1,math.sin(a)*r),(math.cos(b)*r,.19+j*.1,math.sin(b)*r),.065,['e2b66d','c89450','f1ca83'][j])
export('nest')
print('ALL_MODELS_EXPORTED')
