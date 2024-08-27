using UnityEngine;
using System.Collections;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using System;

/// <summary>
/// 控制亮度、饱和度、对比度的后处理效果
/// </summary>
public class BrightnessSaturationAndContrastFeature : ScriptableRendererFeature
{
	/// <summary>
	/// 亮度
	/// </summary>
	[Range(0.0f, 3.0f)]
	public float brightness = 1.0f;

	/// <summary>
	/// 饱和度
	/// </summary>
	[Range(0.0f, 3.0f)]
	public float saturation = 1.0f;

	/// <summary>
	/// 对比度
	/// </summary>
	[Range(0.0f, 3.0f)]
	public float contrast = 1.0f;

    /// <summary>
    /// 这个渲染效果所使用的渲染通道
    /// </summary>
    private BrightnessSaturationAndContrastPass pass;

    public override void Create()
    {
        pass = new BrightnessSaturationAndContrastPass();
        
        // 设定注入点，这里选择了在后期处理之后生效
        // 实际上这个功能自己就是后处理，所以在前面在后面取决于想不想让别的后处理影响到这个后处理
        // 为了不被干扰更好地看到效果就放到后头去了
        pass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 根据摄像机类型注入，这里给游戏摄像机和场景视图注入，没有注入 VR 和其他的一些类型
        // 此外这里支持给预览界面注入，就是点击一个预制后在 inspector 界面下面会出现的那个预览窗口，但这个渲染功能计划上是后处理，可能干扰预览，不注入到预览界面摄像机
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.isSceneViewCamera)
        {
            // 注入通道
            renderer.EnqueuePass(pass);
        }
    }

    /// <summary>
    /// 释放方法，或者你要是愿意也可以叫析构函数，反正他的大名叫 Dispose
    /// </summary>
    /// <param name="disposing"></param>
    protected override void Dispose(bool disposing)
    {
    }
}

/// <summary>
/// 控制亮度、饱和度、对比度的后处理效果使用的自定义通道
/// </summary>
public class BrightnessSaturationAndContrastPass : ScriptableRenderPass, IDisposable
{
	/// <summary>
	/// 亮度
	/// </summary>
	public float brightness = 1.0f;

	/// <summary>
	/// 饱和度
	/// </summary>
	public float saturation = 1.0f;

	/// <summary>
	/// 对比度
	/// </summary>
	public float contrast = 1.0f;

	/// <summary>
	/// 材质，后处理本质是一次渲染，要进行渲染就需要有材质
	/// </summary>
	private Material material;
    /// <summary>
    /// 渲染图片描述符，用于指定管线输入给这个通道的图片的详细要求，用于实现类似 BiRP 的 GrabPass 的功能
    /// </summary>
    private RenderTextureDescriptor textureDescriptor;
    /// <summary>
    /// 渲染图片数据，作为中转存在
    /// </summary>
    private RTHandle textureHandle;

	/// <summary>
	/// 构造方法，并不是什么特别的方法
	/// </summary>
	public BrightnessSaturationAndContrastPass()
	{
		// 这个通道也就只负责使用这个 Shader，可以直接固定用名字获取 Shader 创建材质
		material = CoreUtils.CreateEngineMaterial("Unity Shaders Book/Chapter 12/My Brightness Saturation And Contrast");

        // 创建一个渲染图片输出器
        // 宽高是屏幕宽高，就是全屏输出
        // 默认颜色格式，这个模式是根据平台变化的，但是它不支持 HDR，也有支持 HDR 的默认颜色格式，但在现在这个教程里先不用
        // 深度缓冲区的位数为 0，即不要深度缓冲区信息
        textureDescriptor = new RenderTextureDescriptor(Screen.width, Screen.height, RenderTextureFormat.Default, 0);
	}

    /// <summary>
    /// 配置方法，这个方法会在这个通道正式调用前调用，这个方法不是必须覆写的，根据需要覆写
    /// </summary>
    /// <param name="cmd"></param>
    /// <param name="cameraTextureDescriptor"></param>
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        // 设置图片输出的宽高为摄像机的宽高
        textureDescriptor.width = cameraTextureDescriptor.width;
        textureDescriptor.height = cameraTextureDescriptor.height;

        // 在必要的时候创建一个 RTHandle
        // 按照文档所述如果没有 RTHandle 或者 RTHandle 发生了需要重新创建的变化则会创建新的 RTHandle
        // 总是会传递 RTHandle 给 ref 参数
        RenderingUtils.ReAllocateIfNeeded(ref textureHandle, textureDescriptor);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // 从命令缓冲池里取出命令缓冲
        // 可以理解为这个命令只要执行了流程就会继续走，我们先做自定义的处理，做完后执行这个命令让渲染继续
        CommandBuffer cmd = CommandBufferPool.Get();

        // 取出摄像机的渲染图片
        RTHandle cameraTargetHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;

        // 将摄像机的图片，使用指定材质的 0 号通道，渲染到中转图片
        // 在 Shader 里这个 0 号通道是调色后输出颜色
        // Blit 是一个计算机图形学的词，他指的是从一个图片快速渲染到另一个图片的操作
        Blit(cmd, cameraTargetHandle, textureHandle, material, 0);
        // 将中转图片，使用指定材质的 1 号通道，渲染到摄像机的图片
        // 在 Shader 里这个 1 号通道是直接输出颜色
        Blit(cmd, textureHandle, cameraTargetHandle, material, 1);

        // 执行命令，然后释放掉
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
		// 销毁材质
		CoreUtils.Destroy(material);
    }
}
