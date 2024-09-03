// 控制亮度、饱和度和对比度的 Shader
// 外壳和《入门精要》基本没关系了，但是核心的算法是一样的
Shader "Unity Shaders Book/Chapter 12/My Edge Detection"
{
    Properties
    {
        _EdgeThickness("Edge Thickness", Float) = 1.0
		_EdgeOnly ("Edge Only", Float) = 1.0
		_EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
		_BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
    }
    
    SubShader
    {
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // Blit 包，提供了一些快速的渲染的功能，对于后期处理相当有用
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        ENDHLSL

        Tags {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"
			"Queue" = "Overlay"
        }
        LOD 100
        ZTest Always ZWrite Off Cull Off

        // 调整亮度、饱和度和对比度的通道
        Pass
        {
            Name "Edge"

            HLSLPROGRAM
            
            #pragma vertex Vert // 后期处理都是全屏的不需要什么特殊逻辑，顶点着色器就用 Blit 包里提供的
            #pragma fragment Edge

			half _EdgeThickness;
			half _EdgeOnly;
			half4 _EdgeColor;
			half4 _BackgroundColor;

            // 计算中性灰度色
			half luminance(half4 color) {
				return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
			}

			half Sobel(Varyings input) {
				const half Gx[9] = {-1,  0,  1,
                                    -2,  0,  2,
                                    -1,  0,  1};
				const half Gy[9] = {-1, -2, -1,
                                    0,  0,  0,
                                    1,  2,  1};
                const float2 Gu[9] = {
                    // 以屏幕短边为准
                    input.texcoord + float2(-1, -1) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(0, -1) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(1, -1) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(-1, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(0, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(1, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(-1, 1) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(0, 1) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000)),
                    input.texcoord + float2(1, 1) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y) / 1000))
                };
				
				half texColor;
				half edgeX = 0;
				half edgeY = 0;
				for (int it = 0; it < 9; it++) {
                    texColor = luminance(SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, Gu[it]));
					edgeX += texColor * Gx[it];
					edgeY += texColor * Gy[it];
				}
				
				half edge = 1 - abs(edgeX) - abs(edgeY);
				
				return edge;
			}
            
            float4 Edge (Varyings input) : SV_Target
            {
				half edge = Sobel(input);
				
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
				half4 withEdgeColor = lerp(_EdgeColor, color, edge);
				half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
				return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }
            
            ENDHLSL
        }
        
        // 仅用于原样渲染的通道，由于 Unity 的 Blit 不能源和目标相同，处理的时候就需要将源输出到中转纹理中
        // 但是为了最终渲染结果显示出来需要再输出到 Unity 管线本身的那个输出纹理中，这就需要一个原样渲染的通道
        Pass
        {
            Name "JustBlit" // 名字无所谓，在调用的时候是通过索引调用的

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment SimpleBlit
            
            float4 SimpleBlit (Varyings input) : SV_Target
            {
                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb;
                return float4(color.rgb, 1);
            }

            ENDHLSL
        }
    }
}
