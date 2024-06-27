Shader "Unity Shaders Book/Chapter 7/My-NormalMapTangentSpace"
{
    // 对外暴露的属性
    Properties
    {
        // 纹理贴图
        _MainTexture ("Texture", 2D) = "white" { } // 使用 white 作为默认贴图，这是 Unity 提供的一张纯白贴图
        // 贴图颜色
        _Color ("Texture Tint", Color) = (1, 1, 1, 1)
        // 法线贴图
        _Normal ("Normal Map", 2D) = "bump" { }
        // 法线缩放
        _NormalScale ("Normal Scale", Float) = 1
        // 高光颜色
        _SpecularColor ("Specular", Color) = (1, 1, 1, 1)
        // 光泽，这个值越高则高光会越集中
        _Gloss ("Gloss", Range(8.0, 256)) = 20
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
                // 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
                "LightMode" = "UniversalForward"
            }
    
            // 使用 HLSL 方案
            HLSLPROGRAM
    
            // 指定顶点着色器方法和片元着色器方法
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // 在子着色器内部定义一遍对外暴露的属性，名字需要和属性名完全一样，类型要能够转换过来
            sampler2D _MainTexture;
			float4 _MainTexture_ST; // 对于一个贴图需要有一个 名字_ST 的属性配套，这个属性就是贴图的缩放和偏移的那四个参数
            half4 _Color;
            sampler2D _Normal;
            half4 _Normal_ST;
            float _NormalScale;
            half4 _SpecularColor;
            float _Gloss;

            // 顶点着色器的输入结构
            struct vertexInput
            {
                // 位置
                float4 position: POSITION; // POSITION 语义是 Unity 提供的位置语义，适合作为顶点着色器的输入（因为这个输入是 Unity 发出来的）
                // 法线
                float3 normal: NORMAL;
                // 切线
                float4 tangent: TANGENT;
                // UV 信息，UV 是存储在顶点上的
				float4 texcoord: TEXCOORD0;
            };
            // 顶点着色器向片元着色器传输的数据结构
            struct vertexToFragment
            {
                // 齐次空间的位置
				float4 hPosition: SV_POSITION;
                // 这个片元对应的贴图和法线图的坐标
                float4 uv: TEXCOORD0;
                // 切线空间的光线
                float3 tangentLightDirection: TEXCOORD1;
                // 切线空间的视角
                float3 tangentViewDirection: TEXCOORD2;
            };


            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;

                // 必须有的将位置转为齐次空间
				outputData.hPosition = TransformObjectToHClip(vertexData.position);

                // 用内置方法处理一下 UV 变化，其实就是对着平铺和偏转进行简单的计算
                // 两个 UV 各自存入一个轴，节约一下 TEXCOORD
                // 在实际使用时如果有把握模型的贴图和法线在默认情况就是正确的也可以不进行这个计算，省一些计算量
                outputData.uv.xy = TRANSFORM_TEX(vertexData.texcoord, _MainTexture);
                outputData.uv.zw = TRANSFORM_TEX(vertexData.texcoord, _Normal);
                
                // 创建了一个从世界空间到切线空间的转换矩阵
                // 整个逻辑是固定的，需要一些几何功底才能理解，你要是功底不够就别管细节直接用，不影响
                half3 worldNormal = TransformObjectToWorldNormal(vertexData.normal);
                half3 worldTangent = TransformObjectToWorldDir(vertexData.tangent.xyz);
                float3x3 worldToTangent = CreateTangentToWorld(worldNormal, worldTangent, vertexData.tangent.w);

                // 获取主光源
                Light mainLight = GetMainLight();

                // 转换光线到切线空间并保存
                outputData.tangentLightDirection = TransformWorldToTangentDir(mainLight.direction, worldToTangent);
                // 转换视线到切线空间并保存
                outputData.tangentViewDirection = TransformWorldToTangentDir(GetWorldSpaceViewDir(TransformObjectToWorld(vertexData.position.xyz)), worldToTangent);

                return outputData;
            }

			half4 frag(vertexToFragment input) : SV_Target // SV_Target 语义，基本等同于"COLOR"，但推荐是 SV_Target
            {
                // 漫反射颜色，是贴图的颜色
                // 如果能保证贴图颜色正确且绝不更改的话可以只获取贴图颜色，这样计算量少一些
                half3 albedo = tex2D(_MainTexture, input.uv.xy).rgb * _Color.rgb;

                // 计算法线
                // 先取出并解包，法线是需要解包的，具体的 U3D 帮我们做了
                half3 tangentNormal = UnpackNormal(tex2D(_Normal, input.uv.zw));
                // 调整法线强度，如果发现足够可靠可以不要这一步，省一些计算量
                tangentNormal.xy *= _NormalScale;
                // 根据 xy 轴法线算出 z 轴，这个算法只能保证法线不小于 1，一旦 xy 轴调整强度后的绝对值超过了 1 就会有计算误差，所以非常不推荐在 U3D 环节调整法线强度
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                // 最后归一化一下，实际上属于一种找补，如果上面的计算强度没出问题的话则自然归一，如果强度出了问题的话……都出问题了还用这套法线图？让美术出一张没问题不用调的啊！
                tangentNormal = normalize(tangentNormal);

                // 获取主光源
                Light light = GetMainLight();
                
                // 环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 漫反射光
                half3 diffuse = light.color.rgb * max(0, dot(tangentNormal, input.tangentLightDirection));

                // 高光，Blinn-Phong 模型
                half3 halfDir = normalize(input.tangentLightDirection + input.tangentViewDirection);
                half3 specular = light.color.rgb * _SpecularColor.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                // 环境光和漫反射是受到物体颜色影响的，高光可以理解为像是涂层一样的东西就不受物体颜色影响了
                return half4((diffuse + ambient) * albedo + specular, 1);
			}
    
            ENDHLSL
        }
    }

    // 最终失败转发，如果所有的子着色器都不能用则转发到这个着色器去
    // Diffuse 是 U3D 自带的那个最普通的着色器
    FallBack "Diffuse"
}
