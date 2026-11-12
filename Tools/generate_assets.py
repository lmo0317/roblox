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
cube('Torso',(0,1.75,0),(1.25,1.3,.66),'171c26',.07)
cube('Blue shirt',(0,1.78,-.35),(.48,1.1,.035),'2580d4',.01)
cube('Collar',(0,2.31,-.36),(.47,.15,.05),'174f8b',.025)
cyl('Neck',(0,2.43,0),.24,.22,'f0eff4')
cyl('Head',(0,2.87,0),.43,.84,'f0eff4',vertices=32)
for x in [-.17,.17]:sphere('Eye',(x,2.95,-.40),(.044,.07,.022),'111623')
for i in range(6):
 a=-.15+i*.30/6;b=-.15+(i+1)*.30/6
 rod('Smile',(a,2.67+.10*(a/.15)**2,-.412),(b,2.67+.10*(b/.15)**2,-.412),.015,'111623')
cube('Hair crown',(0,3.27,.04),(.89,.25,.85),'955c28',.12)
for i in range(7):
 x=-.36+i*.12
 strand=cube('Swept fringe',(x,3.20-abs(x)*.28,-.35),(.18,.40,.23),['ac7534','c18b44','865021'][i%3],.065)
 strand.rotation_euler.y=.2
 strand.rotation_euler.z=.25
for x in [-.39,.39]:cube('Sideburn',(x,3.02,.0),(.13,.40,.60),'865021',.05)
for side,x in [('Left',-.89),('Right',.89)]:
 pivot=empty(side+'Arm',(x,2.30,0))
 cube('Sleeve',(0,-.47,0),(.53,.94,.62),'171c26',.07,pivot)
 cube('Hand',(0,-1.08,0),(.48,.35,.58),'f0eff4',.06,pivot)
for side,x in [('Left',-.32),('Right',.32)]:
 pivot=empty(side+'Leg',(x,1.16,0))
 cube('Jeans',(0,-.45,0),(.57,.88,.62),'20232d',.04,pivot)
 cube('Shoe',(0,-1.02,-.08),(.59,.29,.78),'f2f3f8',.05,pivot)
 cube('Sole',(0,-1.15,-.08),(.60,.06,.79),'d5dbe7',.01,pivot)
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
begin()
cube('Chicken body',(0,.8,0),(1.2,1.2,1.4),'fff2d9',.22)
cube('Head',(0,1.55,-.50),(.9,.9,.8),'fff7e7',.15)
for x in [-.26,.26]:sphere('Eye',(x,1.67,-.92),(.06,.09,.04),'20252c')
cyl('Beak',(0,1.40,-1.0),.25,.4,'efa535',vertices=4,r2=0).rotation_euler.x=math.pi/2
for z in [-.65,-.35,-.05]:sphere('Comb',(0,2.08,z),(.16,.25,.20),'dc4141')
for x in [-.55,.55]:cube('Wing',(x,.9,.1),(.30,.70,.9),'e3d1ae',.09)
for x in [-.3,.3]:
 cyl('Leg',(x,.16,0),.08,.40,'e8a73d')
 cube('Foot',(x,.05,-.15),(.32,.10,.45),'e8a73d',.02)
export('chicken')
begin()
cube('Croc body',(0,.55,.1),(1.4,.9,2.6),'548044',.12)
cube('Head',(0,.8,-1.6),(1.5,.7,1.5),'66964e',.12)
cube('Mouth',(0,.55,-1.8),(1.47,.10,1.3),'e0ce9d',.025)
for x in [-.5,.5]:
 sphere('Eye mount',(x,1.18,-1.1),(.25,.25,.25),'66964e')
 sphere('Eye',(x,1.2,-1.31),(.08,.11,.04),'142522')
 for z in [-.7,.8]:cube('Leg',(x*1.5,.25,z),(.45,.45,.8),'466d3c',.05)
for z in [-.5,0,.5,1]:cyl('Spine',(0,1.13,z),.22,.40,'365734',vertices=3,r2=0)
rod('Tail',(0,.6,1.2),(0,.45,2.5),.35,'548044')
export('crocodile')
begin()
cube('Body',(0,1.5,0),(2.0,2.0,2.6),'776b92',.25)
cube('Head',(0,2.0,-1.3),(1.9,1.8,1.4),'8d7da4',.22)
for x in [-.9,.9]:
 cube('Ear',(x,2.0,-1.1),(.35,1.4,1.0),'a593bb',.16)
 sphere('Eye',(x*.72,2.2,-2.02),(.09,.12,.04),'212735')
 rod('Tusk',(x*.65,1.5,-1.9),(x*.85,1.9,-2.6),.13,'fff5d2')
rod('Trunk upper',(0,1.9,-1.95),(0,.9,-2.3),.30,'8d7da4')
rod('Trunk tip',(0,.9,-2.3),(0,.45,-2.9),.24,'8d7da4')
for x in [-.6,.6]:
 for z in [-.75,.8]:
  cube('Leg',(x,.5,z),(.7,1.0,.8),'6d6286',.1)
  cube('Toenails',(x,.14,z-.42),(.48,.20,.07),'d5c7dd',.03)
export('mammoth')
print('ALL_MODELS_EXPORTED')
