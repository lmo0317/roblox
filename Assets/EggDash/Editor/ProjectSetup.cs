using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace EggDash.Editor
{
    [InitializeOnLoad]
    public static class ProjectSetup
    {
        const string ScenePath="Assets/Scenes/EggDash.unity";
        static ProjectSetup() { EditorApplication.delayCall += Prepare; }
        static void Prepare()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) return;
            if(System.IO.File.Exists(ScenePath)) return;
            CreateScene();
        }
        [MenuItem("Egg Dash/Create or Open Game Scene")]
        public static void CreateScene()
        {
            if(System.IO.File.Exists(ScenePath)) { EditorSceneManager.OpenScene(ScenePath); return; }
            if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            new GameObject("Egg Dash Runtime").AddComponent<EggDashGame>();
            EditorSceneManager.SaveScene(scene,ScenePath);
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(ScenePath,true)};
            PlayerSettings.productName="Egg Dash"; PlayerSettings.companyName="EggDash";
            PlayerSettings.defaultScreenWidth=1280; PlayerSettings.defaultScreenHeight=720;
            AssetDatabase.SaveAssets();
        }
        // Unity -batchmode -projectPath ... -executeMethod EggDash.Editor.ProjectSetup.BuildLinux -quit
        public static void BuildLinux()
        {
            CreateScene();
            var report=BuildPipeline.BuildPlayer(new[]{ScenePath},"Build/Linux/EggDash",BuildTarget.StandaloneLinux64,BuildOptions.None);
            if(report.summary.result!=UnityEditor.Build.Reporting.BuildResult.Succeeded)
                throw new System.Exception("Egg Dash Linux build failed: "+report.summary.result);
        }
    }
}
