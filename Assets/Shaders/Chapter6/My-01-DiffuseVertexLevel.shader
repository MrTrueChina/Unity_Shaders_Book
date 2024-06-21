Shader "Unity Shaders Book/Chapter 6/My-DiffuseVertexLevel"
{
    // 对外暴露的属性
    Properties
    {
        // 对外属性的格式是这样的： _名字 ("外部显示的接口名字", 类型) = 值
        // 其中名字一定要是下划线开头，否则可能发生编译问题
        // 漫反射颜色，就是物体可以反射的光的颜色，也是物体在白光下的颜色
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
    }
    SubShader
    {
        Pass
        {
            Tags
            {
                // 使用通用渲染管线（URP）
                "RenderPipeline" = "UniversalPipeline"
                // 渲染类型为不透明
                "RenderType" = "Opaque"
                // 光照模式为 URP正向渲染路径（翻译可能不准确，这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
                "LightMode" = "UniversalForward"
            }
    
            // 使用 HLSL 方案
            HLSLPROGRAM
    
            // 指定顶点着色器方法和片元着色器方法
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // 在子着色器内部定义一遍对外暴露的属性，名字需要和属性名完全一样，类型要能够转换过来
            half4 _Diffuse;

            // 顶点着色器的输入结构
            struct vertexInput
            {
                // 这里面定义的属性格式是这样的：类型 属性名: 语义
                // 语义是一个传统 C 系里没有的东西，你可以理解为语义是给变量声明时候的参数，决定了这个变量的一些功能和作用
                // 举个例子 POSITION 语义的意思是这个变量要用于存储位置，作为输入变量时管线就会将顶点位置传给这个变量，我们就可以利用这个位置信息进行一些处理之后再回传给管线让管线继续走下去完成渲染
                // 同样的 NORMAL 的语义就是指这个变量要用于存储法线，管线会将顶点的法线信息传给这个变量

                // 基于这样的原理你一定也猜到了，语义是有一定规则的，而对于这个规则我只能说现用现查吧，Unity ShdaerLab 的变动还是挺频繁的

                // 位置
                float4 position: POSITION;
                // 法线
                float3 normal: NORMAL;
            };
            // 顶点着色器向片元着色器传输的数据结构
            struct vertexToFragment
            {
                // 位置是必须的，没有这个位置则片元着色器不知道要在哪里绘制，即使片元着色器代码里没用到也要带这个属性
				float4 pos : SV_POSITION;
                // 因为这个着色器是不透明的，颜色只要传 RGB，half3 就够了
                half3 color: COLOR;
            };


            // 顶点着色器处理方法
            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;

				// 将顶点坐标从物体空间坐标转到齐次空间(homogenous space)坐标
				// 齐次空间是一个几何的概念，如果几何基础不够很难解释也很难理解，可以简单的理解为和世界空间类似的对所有物体都统一标准的空间坐标系，但齐次空间的坐标和世界空间坐标不一定是相同的
                // PS: 如果有探索精神的话可以试试不进行转换直接存入，效果会很有趣，可以帮助你理解世界空间、物体本地空间、齐次空间的差异和关系
				outputData.pos = TransformObjectToHClip(vertexData.position);

                // 获取主光源
                Light light = GetMainLight();

                // 将顶点空间的法线转为世界空间的法线
				half3 worldNormal = TransformObjectToWorldNormal(vertexData.normal);

                // 计算角度对亮度的影响
                // 原理是向量的点积，点积是集合了角度和长度(标准来说叫“模”)的乘法，向量的朝向越近则数值越大，向量之间的角度到达 90 度就为零，更大则为负数
                // 利用法线和光线的点积就正好可以让朝向光的面为正数而背光面是负数，再用限制一下范围为 0-1 就大功告成
                // saturate: 类似于 Mathf.Clamp，限制为 0-1；dot：求点积；世界空间法线和光线朝向的模都是 1，所以点积不会超过 1，不需要再做处理
                half brightness = saturate(dot(worldNormal, light.direction));

                // 颜色是乘法，因为漫反射颜色是反射光中可以反射的颜色
                // 假设一个物体颜色是 (0,0,1) 纯蓝色，光线是 (1,0,0) 纯红色，那么没有蓝色光给物体反射物体就应该是纯黑色，乘法正好可以做到这一点
                // 最后还要乘以角度产生的亮度影响
                outputData.color = _Diffuse.rgb * light.color.rgb * brightness;

                return outputData;
            }

            // 片元着色器处理方法
			half4 frag(vertexToFragment input) : SV_Target {
                // 片元着色器啥都不用干，把颜色输出就行，因为这个 shader 是不透明的，透明度就是 1
				return half4(input.color, 1.0);
			}
    
            ENDHLSL
        }
    }

    // 最终失败转发，如果所有的子着色器都不能用则转发到这个着色器去
    // Diffuse 是 U3D 自带的那个最普通的着色器
    FallBack "Diffuse"
}
