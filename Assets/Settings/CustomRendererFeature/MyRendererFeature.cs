using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class MyRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private Shader shader;
    private Material material;
    private RedTintRenderPass redTintRenderPass;

    public override void Create()
    {
        if (shader == null)
        {
            return;
        }
        material = CoreUtils.CreateEngineMaterial(shader);
        redTintRenderPass = new RedTintRenderPass(material);
        
        redTintRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType == CameraType.Game)
        {
            renderer.EnqueuePass(redTintRenderPass);
        }
    }
    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(material);
    }
}