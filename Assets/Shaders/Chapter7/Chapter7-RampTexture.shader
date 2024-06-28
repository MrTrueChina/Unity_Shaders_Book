﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 7/Ramp Texture" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_RampTex ("Ramp Tex", 2D) = "white" {}
		_Specular ("Specular", Color) = (1, 1, 1, 1)
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
		
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
			
			half4 _Color;
			sampler2D _RampTex;
			float4 _RampTex_ST;
			half4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float2 uv : TEXCOORD2;
			};
			
            v2f vert(a2v v)
            {
                v2f o;

                o.pos = TransformObjectToHClip(v.vertex);
                
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                
                o.worldPos = TransformObjectToWorld(v.vertex);
                
                o.uv = TRANSFORM_TEX(v.texcoord, _RampTex);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                // 获取主光源
                Light light = GetMainLight();

                // 环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
                // Use the texture to sample the diffuse color
                half halfLambert = 0.5 * dot(i.worldNormal, light.direction) + 0.5;
                half3 diffuseColor = tex2D(_RampTex, half2(halfLambert, halfLambert)).rgb * _Color.rgb;
                
                half3 diffuse = light.color.rgb * diffuseColor;
                
                half3 viewDir = normalize(GetWorldSpaceViewDir(i.worldPos));
                half3 halfDir = normalize(light.direction + viewDir);
                half3 specular = light.color.rgb * _Specular.rgb * pow(max(0, dot(i.worldNormal, halfDir)), _Gloss);
                
                return half4(ambient + diffuse + specular, 1.0);
            }
			
			ENDHLSL
		}
	} 
	FallBack "Specular"
}
