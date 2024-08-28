// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 12/My Brightness Saturation And Contrast"
{
    Properties
    {
        _Brightness ("Brightness", Float) = 1
        _Saturation ("Saturation", Float) = 1
        _Contrast ("Contrast", Float) = 1
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

        Pass
        {
            Name "Red"

            HLSLPROGRAM
            
            #pragma vertex Vert // 后期处理都是全屏的不需要什么特殊逻辑，顶点着色器就用 Blit 包里提供的
            #pragma fragment RedTint

            float _Brightness;
            float _Saturation;
            float _Contrast;
            
            float4 RedTint (Varyings input) : SV_Target
            {
                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb;
                return float4((_Brightness + _Saturation + _Contrast) / 3, color.gb, 1);
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
