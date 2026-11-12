using System;
using System.Collections.Generic;
using UnityEngine;

namespace EggDash
{
    // All visuals are original primitive meshes. No external assets required.
    public sealed class EggDashGame : MonoBehaviour
    {
        enum Phase { Ready, Carrying, Hatching }
        const string SaveKey = "EggDash.Save.v1";
        [Serializable] sealed class SaveData { public int coins=100, speed=0, capacity=0, pets=0; }
        sealed class Nest { public Vector3 position; public Transform egg; public float respawn; public bool rare; }
        sealed class Pet { public Transform body; public Vector3 home; }
        readonly List<Nest> nests = new List<Nest>();
        readonly List<Pet> pets = new List<Pet>();
        readonly Dictionary<string,Material> materials = new Dictionary<string,Material>();
        SaveData save = new SaveData();
        CharacterController controller;
        Transform avatar, guardian, carriedEgg, cameraRig;
        Transform leftArm,rightArm,leftLeg,rightLeg;
        Camera view;
        Phase phase;
        float yaw=0, pitch=25, vertical, hatchTime, incomeClock, saveClock, messageTime, gait, guardianGrace;
        bool rareCarry, paused;
        int caughtCount;
        string message="둥지에서 E 키로 알을 가져오세요!";
        readonly Vector3 spawn = new Vector3(0,0,-9);
        readonly Vector3 hatchPad = new Vector3(0,0,-12);
        readonly Vector3 guardianHome = new Vector3(-11,0,11);
        GUIStyle label, title, small, button;
        Font font;
        bool korean;

        void Awake()
        {
            Application.targetFrameRate=60;
            Load(); BuildWorld(); BuildPlayer();
            view=new GameObject("Third Person Camera").AddComponent<Camera>();
            view.fieldOfView=65; view.farClipPlane=150; view.backgroundColor=new Color(.35f,.72f,1);
            view.clearFlags=CameraClearFlags.SolidColor;
            view.gameObject.AddComponent<AudioListener>(); cameraRig=view.transform;
            foreach(string name in Font.GetOSInstalledFontNames())
                if(name.Contains("Malgun") || name.Contains("Noto Sans CJK") || name.Contains("Apple SD Gothic"))
                { font=Font.CreateDynamicFontFromOSFont(name,20); korean=true; break; }
            if(font==null) font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if(!korean) message="Press E at a nest to pick up an egg!";
            messageTime=8;
            for(int i=0;i<save.pets;i++) AddPet();
        }
        string T(string ko,string en) { return korean?ko:en; }
        Material Mat(string hex)
        {
            if(materials.TryGetValue(hex,out var found)) return found;
            Shader shader=Shader.Find("Standard");
            var material=new Material(shader); ColorUtility.TryParseHtmlString(hex,out var color);
            material.color=color; material.SetFloat("_Glossiness",.08f); materials.Add(hex,material); return material;
        }
        Transform Part(string name,Vector3 position,Vector3 scale,string color,Transform parent=null,PrimitiveType type=PrimitiveType.Cube,bool solid=true)
        {
            var obj=GameObject.CreatePrimitive(type); obj.name=name; obj.transform.SetParent(parent,false);
            obj.transform.localPosition=position; obj.transform.localScale=scale;
            obj.GetComponent<Renderer>().sharedMaterial=Mat(color);
            if(!solid) Destroy(obj.GetComponent<Collider>());
            return obj.transform;
        }
        void Sign(string text,Vector3 position,int size=32,float scale=.11f)
        {
            var obj=new GameObject("Sign "+text); obj.transform.position=position;
            var tm=obj.AddComponent<TextMesh>(); tm.text=text; tm.fontSize=size; tm.characterSize=scale;
            tm.anchor=TextAnchor.MiddleCenter; tm.alignment=TextAlignment.Center; tm.color=Color.white;
            obj.transform.rotation=Quaternion.Euler(0,180,0);
        }
        void BuildWorld()
        {
            RenderSettings.ambientLight=new Color(.68f,.74f,.85f);
            var sun=new GameObject("Sun").AddComponent<Light>(); sun.type=LightType.Directional;
            sun.intensity=1.15f; sun.shadows=LightShadows.Soft; sun.transform.rotation=Quaternion.Euler(48,-35,0);
            Part("Grass",new Vector3(0,-.6f,5),new Vector3(54,1,58),"#65BB40");
            Part("Main road",new Vector3(0,-.06f,3),new Vector3(5,.1f,36),"#A8ADB3");
            Part("Crossroad",new Vector3(0,-.05f,3),new Vector3(38,.1f,4),"#A8ADB3");
            for(int i=0;i<4;i++)
            {
                float x=i%2==0?-24:24; float z=-10+i*11;
                Part("Tree trunk",new Vector3(x,1.5f,z),new Vector3(1,3,1),"#916037");
                Part("Tree canopy",new Vector3(x,4,z),new Vector3(4,3,4),"#32943B");
            }
            Base(Vector3.zero,"#2580EA","YOUR BASE");
            Base(new Vector3(-17,0,19),"#E75555","RED BASE");
            Base(new Vector3(17,0,19),"#9859D8","PURPLE BASE");
            Part("Hatch pad",hatchPad+Vector3.up*.08f,new Vector3(3,.18f,3),"#5CE5FF");
            Sign("HATCH",hatchPad+new Vector3(0,.5f,.7f),28,.08f);
            Part("Treadmill",new Vector3(9,.3f,-12),new Vector3(2,.6f,4),"#394554");
            Part("Treadmill screen",new Vector3(9,1.8f,-10.4f),new Vector3(2,1,.3f),"#2580EA");
            Sign("SPEED UPGRADE",new Vector3(9,3,-11));
            Part("Base upgrade",new Vector3(-9,.12f,-12),new Vector3(3,.25f,3),"#F5B92C");
            Sign("BASE UPGRADE",new Vector3(-9,2,-12));
            CreateNest(new Vector3(-11,0,11),false);
            CreateNest(new Vector3(11,0,12),false);
            CreateNest(new Vector3(0,0,26),true);
            Part("Rare biome",new Vector3(0,-.04f,26),new Vector3(17,.15f,9),"#EAD38A");
            Sign("RARE EGGS / SPEED LV 3",new Vector3(0,4,23));
            for(int i=0;i<2;i++) Part("Gate",new Vector3(i==0?-5:5,2,22),new Vector3(.6f,4,.6f),"#E9B531");
            guardian=new GameObject("Fox guardian").transform; guardian.position=guardianHome;
            Part("Fox body",new Vector3(0,1,0),new Vector3(2,1.4f,2.8f),"#EA7F20",guardian,solid:false);
            Part("Fox head",new Vector3(0,1.9f,1.1f),new Vector3(2,1.6f,1.6f),"#F29230",guardian,solid:false);
            Part("Muzzle",new Vector3(0,1.6f,2),new Vector3(1.4f,.6f,.5f),"#FFF2DA",guardian,solid:false);
            for(int i=0;i<2;i++) {
                Part("Ear",new Vector3(i==0?-.65f:.65f,2.95f,1),new Vector3(.5f,.7f,.5f),"#EA7F20",guardian,solid:false);
                Part("Eye",new Vector3(i==0?-.5f:.5f,2.05f,1.92f),new Vector3(.2f,.25f,.1f),"#202B39",guardian,solid:false);
            }
            Part("Tail",new Vector3(0,1,-1.8f),new Vector3(.6f,.7f,1.5f),"#FFFFFF",guardian,solid:false);
        }
        void Base(Vector3 offset,string color,string name)
        {
            Vector3 origin=new Vector3(offset.x,0,offset.z-16);
            Part(name+" floor",origin+new Vector3(0,.05f,0),new Vector3(13,.2f,6),"#CFD8E5");
            Part(name+" back",origin+new Vector3(0,2,-3),new Vector3(13,4,.4f),color);
            Part(name+" roof",origin+new Vector3(0,4,0),new Vector3(13,.4f,6),color);
            for(int i=0;i<2;i++) Part("Column",origin+new Vector3(i==0?-6:6,2,2.5f),new Vector3(.5f,4,.5f),color);
            Sign(name,origin+new Vector3(0,4.5f,3));
        }
        void CreateNest(Vector3 p,bool rare)
        {
            Part("Nest",p+Vector3.up*.18f,new Vector3(2.4f,.4f,2.4f),"#9E703F");
            var n=new Nest{position=p,rare=rare}; nests.Add(n); SpawnEgg(n);
        }
        void SpawnEgg(Nest n)
        {
            n.egg=Part(n.rare?"Rare egg":"Egg",n.position+Vector3.up*1.1f,new Vector3(1,1.35f,1),n.rare?"#E9B3FF":"#B7F1FC",type:PrimitiveType.Sphere,solid:false);
        }
        void BuildPlayer()
        {
            var obj=new GameObject("Player"); avatar=obj.transform; avatar.position=spawn;
            controller=obj.AddComponent<CharacterController>(); controller.height=3.1f; controller.radius=.48f; controller.center=Vector3.up*1.55f; controller.stepOffset=.35f;
            Part("Torso",new Vector3(0,1.65f,0),new Vector3(1.2f,1.2f,.7f),"#EF443C",avatar,solid:false);
            Part("Head",new Vector3(0,2.65f,0),Vector3.one*.85f,"#FFD84A",avatar,solid:false);
            Part("Hair",new Vector3(0,3.08f,-.04f),new Vector3(.9f,.25f,.9f),"#303744",avatar,solid:false);
            for(int i=0;i<2;i++) Part("Eye",new Vector3(i==0?-.19f:.19f,2.72f,.44f),new Vector3(.09f,.12f,.04f),"#243040",avatar,solid:false);
            Part("Smile",new Vector3(0,2.47f,.44f),new Vector3(.24f,.05f,.04f),"#243040",avatar,solid:false);
            leftArm=Part("Left arm",new Vector3(-.94f,1.6f,0),new Vector3(.55f,1.2f,.65f),"#FFD84A",avatar,solid:false);
            rightArm=Part("Right arm",new Vector3(.94f,1.6f,0),new Vector3(.55f,1.2f,.65f),"#FFD84A",avatar,solid:false);
            leftLeg=Part("Left leg",new Vector3(-.32f,.5f,0),new Vector3(.58f,1,.65f),"#287CE2",avatar,solid:false);
            rightLeg=Part("Right leg",new Vector3(.32f,.5f,0),new Vector3(.58f,1,.65f),"#287CE2",avatar,solid:false);
        }
        void Update()
        {
            if(Input.GetKeyDown(KeyCode.Escape)) paused=!paused;
            if(paused) return;
            float dt=Time.deltaTime;
            if(messageTime>0) messageTime-=dt;
            guardianGrace=Mathf.Max(0,guardianGrace-dt);
            if(Input.GetMouseButton(1)) { yaw+=Input.GetAxis("Mouse X")*3; pitch=Mathf.Clamp(pitch-Input.GetAxis("Mouse Y")*2,10,65); }
            Vector3 input=new Vector3(Input.GetAxisRaw("Horizontal"),0,Input.GetAxisRaw("Vertical")).normalized;
            Vector3 direction=Quaternion.Euler(0,yaw,0)*input;
            bool sprint=Input.GetKey(KeyCode.LeftShift);
            float speed=(6+save.speed*1.2f)*(sprint?1.45f:1)*(phase==Phase.Carrying?.82f:1);
            if(controller.isGrounded && vertical<0) vertical=-2;
            if(Input.GetKeyDown(KeyCode.Space) && controller.isGrounded) vertical=8;
            vertical-=22*dt;
            controller.Move((direction*speed+Vector3.up*vertical)*dt);
            if(direction.sqrMagnitude>.01f) avatar.rotation=Quaternion.Slerp(avatar.rotation,Quaternion.LookRotation(direction),dt*12);
            gait+=dt*speed*1.8f;
            float swing=direction.sqrMagnitude>.01f?Mathf.Sin(gait)*28:0;
            leftLeg.localRotation=Quaternion.Euler(swing,0,0); rightLeg.localRotation=Quaternion.Euler(-swing,0,0);
            leftArm.localRotation=Quaternion.Euler(phase==Phase.Carrying?-65:-swing,0,0);
            rightArm.localRotation=Quaternion.Euler(phase==Phase.Carrying?-65:swing,0,0);
            if(Mathf.Abs(avatar.position.x)>26 || avatar.position.z>33 || avatar.position.z< -23 || avatar.position.y< -5) ResetPlayer(false);
            if(Input.GetKeyDown(KeyCode.E)) Interact();
            UpdateEggs(dt); UpdateGuardian(dt);
            incomeClock+=dt; if(incomeClock>=1) { int ticks=Mathf.FloorToInt(incomeClock); incomeClock-=ticks; save.coins+=save.pets*12*ticks; }
            saveClock+=dt; if(saveClock>10) { saveClock=0; Persist(); }
            foreach(var pet in pets) pet.body.position=pet.home+Vector3.up*(Mathf.Sin(Time.time*2+pet.home.x)*.08f);
        }
        void LateUpdate()
        {
            if(view==null) return;
            Vector3 target=avatar.position+Vector3.up*1.8f;
            Vector3 desired=target+Quaternion.Euler(pitch,yaw,0)*new Vector3(0,0,-9);
            if(Physics.Linecast(target,desired,out var hit,~0,QueryTriggerInteraction.Ignore))
                if(hit.collider!=controller) desired=hit.point+hit.normal*.3f;
            cameraRig.position=Vector3.Lerp(cameraRig.position,desired,1-Mathf.Exp(-12*Time.deltaTime));
            cameraRig.LookAt(target);
        }
        void Interact()
        {
            Vector3 p=avatar.position;
            if(phase==Phase.Carrying && Vector3.Distance(p,hatchPad)<3)
            {
                if(save.pets>=Capacity) { Notify(T("기지를 업그레이드하세요!","Base full! Upgrade your base.")); return; }
                phase=Phase.Hatching; hatchTime=3; Destroy(carriedEgg.gameObject); carriedEgg=null;
                Notify(T("부화 중…","Hatching...")); return;
            }
            if(Vector3.Distance(p,new Vector3(9,0,-12))<3) { Upgrade(true); return; }
            if(Vector3.Distance(p,new Vector3(-9,0,-12))<3) { Upgrade(false); return; }
            if(phase!=Phase.Ready) return;
            foreach(var n in nests)
            {
                if(n.egg==null || Vector3.Distance(p,n.position)>3) continue;
                if(n.rare && save.speed<3) { Notify(T("속도 레벨 3이 필요합니다!","Requires speed level 3!")); return; }
                if(save.pets>=Capacity) { Notify(T("기지가 가득 찼습니다!","Base full! Upgrade first.")); return; }
                rareCarry=n.rare; carriedEgg=n.egg; n.egg=null; n.respawn=8;
                carriedEgg.SetParent(avatar,false); carriedEgg.localPosition=new Vector3(0,1.8f,1);
                carriedEgg.localScale=new Vector3(1,1.35f,1); phase=Phase.Carrying;
                Notify(T("알을 파란 부화 패드로 가져가세요!","Return to the blue HATCH pad!")); break;
            }
        }
        void UpdateEggs(float dt)
        {
            foreach(var n in nests) { if(n.egg==null) { n.respawn-=dt; if(n.respawn<=0) SpawnEgg(n); } else n.egg.Rotate(0,25*dt,0); }
            if(phase!=Phase.Hatching) return;
            hatchTime-=dt; if(hatchTime>0) return;
            save.pets++; if(rareCarry) save.coins+=150; AddPet(); phase=Phase.Ready;
            Notify(T("새 펫! 초당 수익 +12","New pet! Income +$12/s")+(rareCarry?" / BONUS $150":"")); Persist();
        }
        void UpdateGuardian(float dt)
        {
            bool chase=phase==Phase.Carrying && avatar.position.z> -5 && guardianGrace<=0;
            Vector3 target=chase?avatar.position:guardianHome+new Vector3(Mathf.Sin(Time.time*.4f)*4,0,Mathf.Cos(Time.time*.4f)*3);
            target.y=0; Vector3 diff=target-guardian.position;
            if(diff.sqrMagnitude>.1f) { guardian.rotation=Quaternion.Slerp(guardian.rotation,Quaternion.LookRotation(diff),dt*6); guardian.position=Vector3.MoveTowards(guardian.position,target,dt*(chase?6.8f:2)); }
            if(chase && Vector3.Distance(guardian.position,avatar.position)<1.6f) ResetPlayer(true);
        }
        void ResetPlayer(bool caught)
        {
            if(carriedEgg!=null) Destroy(carriedEgg.gameObject);
            if(phase==Phase.Carrying) phase=Phase.Ready;
            controller.enabled=false; avatar.position=spawn; controller.enabled=true; vertical=0; guardianGrace=3;
            if(caught) caughtCount++;
            Notify(caught?T("잡혔어요! 알을 다시 가져오세요.","Caught! Try another egg."):T("기지로 돌아왔습니다.","Returned to base."));
        }
        int Capacity => 3+save.capacity*3;
        int SpeedCost => 100*(save.speed+1);
        int BaseCost => 250*(save.capacity+1);
        void Upgrade(bool speed)
        {
            int cost=speed?SpeedCost:BaseCost;
            if((speed && save.speed>=10)||(!speed && save.capacity>=3)) { Notify(T("최대 레벨입니다.","Maximum level reached.")); return; }
            if(save.coins<cost) { Notify(T("코인이 부족합니다!","Not enough coins!")); return; }
            save.coins-=cost; if(speed) save.speed++; else save.capacity++;
            Notify(T("업그레이드 완료!","Upgrade complete!")); Persist();
        }
        void AddPet()
        {
            int i=pets.Count; Vector3 home=new Vector3(-4+(i%6)*1.6f,.7f,-17+(i/6)*1.8f);
            Transform root=new GameObject("Pet "+(i+1)).transform; root.position=home;
            string color=i%2==0?"#ADB9CC":"#76D54D";
            Part("Cube pet",Vector3.zero,Vector3.one*.9f,color,root,solid:false);
            for(int j=0;j<2;j++) {
                Part("Eye",new Vector3(j==0?-.23f:.23f,.12f,.47f),new Vector3(.12f,.16f,.06f),"#202B39",root,solid:false);
                Part("Ear",new Vector3(j==0?-.3f:.3f,.55f,0),new Vector3(.23f,.3f,.3f),color,root,solid:false);
            }
            Part("Income pad",home+new Vector3(0,-.48f,.8f),new Vector3(1.1f,.12f,.6f),"#86F233");
            pets.Add(new Pet{body=root,home=home});
        }
        void Notify(string text) { message=text; messageTime=5; }
        void Load()
        {
            try { if(PlayerPrefs.HasKey(SaveKey)) save=JsonUtility.FromJson<SaveData>(PlayerPrefs.GetString(SaveKey))??new SaveData(); }
            catch { save=new SaveData(); }
            save.speed=Mathf.Clamp(save.speed,0,10); save.capacity=Mathf.Clamp(save.capacity,0,3);
            save.pets=Mathf.Clamp(save.pets,0,Capacity); save.coins=Mathf.Clamp(save.coins,0,100000000);
        }
        void Persist() { PlayerPrefs.SetString(SaveKey,JsonUtility.ToJson(save)); PlayerPrefs.Save(); }
        void OnApplicationQuit() { Persist(); }
        void OnApplicationPause(bool value) { if(value) Persist(); }
        void OnGUI()
        {
            if(font==null) return;
            if(label==null) {
                label=new GUIStyle(GUI.skin.label){font=font,fontSize=22,alignment=TextAnchor.MiddleLeft}; label.normal.textColor=Color.white;
                title=new GUIStyle(label){fontSize=32,fontStyle=FontStyle.Bold};
                small=new GUIStyle(label){fontSize=17,wordWrap=true};
                button=new GUIStyle(GUI.skin.button){font=font,fontSize=19};
            }
            Matrix4x4 previous=GUI.matrix; GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1280f,Screen.height/720f,1));
            Panel(new Rect(18,15,260,65)); GUI.Label(new Rect(32,22,245,50),"EGG DASH",title);
            Panel(new Rect(980,15,280,110));
            GUI.Label(new Rect(995,22,250,40),"$ "+save.coins.ToString("N0"),title);
            GUI.Label(new Rect(995,68,250,45),$"SPEED {save.speed}  |  +${save.pets*12}/s",small);
            Panel(new Rect(18,95,245,125));
            GUI.Label(new Rect(30,102,225,105),T($"펫 {save.pets}/{Capacity}\n속도 강화 ${SpeedCost}\n기지 확장 ${BaseCost}",$"PETS {save.pets}/{Capacity}\nSpeed upgrade ${SpeedCost}\nBase upgrade ${BaseCost}"),small);
            if(messageTime>0 || phase==Phase.Carrying) {
                Panel(new Rect(300,20,650,65));
                GUI.Label(new Rect(315,25,620,55),message,small);
            }
            if(phase==Phase.Hatching) GUI.Label(new Rect(460,290,400,60),T("부화 중 ","HATCHING ")+Mathf.CeilToInt(hatchTime),title);
            Panel(new Rect(190,625,900,78));
            GUI.Label(new Rect(210,632,860,65),T("WASD 이동 · Space 점프 · Shift 달리기 · 마우스 우클릭 시점\nE 알 가져오기 / 부화 / 업그레이드 · Esc 일시정지","WASD Move  |  Space Jump  |  Shift Sprint  |  Hold RMB + Mouse Orbit\nE Pick up / Hatch / Upgrade  |  Esc Pause"),small);
            if(phase==Phase.Carrying) GUI.Label(new Rect(450,565,500,45),T("파란 HATCH 패드에서 E!","Press E on the blue HATCH pad!"),label);
            if(paused) {
                Panel(new Rect(390,220,500,300));
                GUI.Label(new Rect(420,240,440,60),T("일시정지","PAUSED"),title);
                if(GUI.Button(new Rect(430,320,420,55),T("계속하기","Resume"),button)) paused=false;
                GUI.Label(new Rect(430,390,420,90),T("진행 상황은 자동 저장됩니다.\n플레이 모드를 종료해도 유지됩니다.","Progress saves automatically.\nSingle-player prototype."),small);
            }
            GUI.matrix=previous;
        }
        void Panel(Rect rect) { Color old=GUI.color; GUI.color=new Color(.08f,.14f,.24f,.92f); GUI.DrawTexture(rect,Texture2D.whiteTexture); GUI.color=old; }
    }
}
