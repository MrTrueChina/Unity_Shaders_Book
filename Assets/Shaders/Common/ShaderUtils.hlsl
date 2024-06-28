#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

/// 计算漫反射颜色
/// @param color 物体本身的漫反射颜色
/// @param normal 法线
/// @param lightDirection 光线方向
half3 GetDiffuseColor(half3 color, half3 normal, half3 lightDirection)
{
    // 简单的点积，当向量垂直后点积就从 0 逐渐变为负数，正好可以计算光照受到角度影响的效果
    return color.rgb * max(0, dot(normal, lightDirection));
}

/// 获取高光颜色，Blinn-Phong 模型
/// @param lightDirection 光线方向
/// @param normal 法线
/// @param viewDirection 视线方向
/// @param specularColor 高光颜色
/// @param lightColor 光线颜色
/// @param gloss 高光集中程度
/// @return 高光颜色
half3 GetSpecualrColorBlinnPhong(half3 lightDirection, half3 normal, half3 viewDirection, half3 specularColor, half3 lightColor, half gloss)
{
    // Blinn-Phong 模型的高光计算，用视线和光线的中间方向和法线进行计算
    // 比起传统 Blinn 模型的优点是不用计算反射，效率上一般会更好一些
    // 因为 Blinn 模型也是经验模型，大部分情况下两个模型视觉效果不同但都 “看上去对”
    half3 halfDir = normalize(lightDirection + viewDirection);
    return lightColor.rgb * specularColor.rgb * pow(max(dot(normal, halfDir), 0.0), gloss);
}

/// 使用物体空间的向量创建世界空间到切线空间的向量转换矩阵
/// @param objectSpaceNormal 物体空间法线
/// @param objectSpaceTangent 物体空间切线
/// @return 世界空间到切线空间的转换矩阵
float3x3 CreateWorldToTangentByObject(half3 objectSpaceNormal, half4 objectSpaceTangent)
{
    // 具体的算法需要一些几何功底才能理解，你要是功底不够就别管细节直接用，不影响
    return CreateTangentToWorld(TransformObjectToWorldNormal(objectSpaceNormal), TransformObjectToWorldDir(objectSpaceTangent.xyz), objectSpaceTangent.w);
}

/// 解包切线空间法线贴图并返回法线，能够进行不准确的法线强度调整【注意】如果可以获取到不需要调整的法线贴图请尽可能直接使用 UnpackNormal
/// @param normalMap 法线贴图
/// @param uv 贴图坐标
/// @param scale 法线强度调整
half3 UnpackTangentSpaceNormal(sampler2D normalMap, float2 uv, float scale)
{
    // 先取出并解包，法线是需要解包的，具体的 U3D 帮我们做了
    half3 tangentNormal = UnpackNormal(tex2D(normalMap, uv));
    // 调整法线强度，如果发现足够可靠可以不要这一步，省一些计算量
    tangentNormal.xy *= scale;
    // 根据 xy 轴法线算出 z 轴，这个算法只能保证法线不小于 1，一旦 xy 轴调整强度后的绝对值超过了 1 就会有计算误差，所以非常不推荐在 U3D 环节调整法线强度
    tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
    // 最后归一化一下，实际上属于一种找补，如果上面的计算强度没出问题的话则自然归一，如果强度出了问题的话……都出问题了还用这套法线图？让美术出一张没问题不用调的啊！
    return normalize(tangentNormal);
}