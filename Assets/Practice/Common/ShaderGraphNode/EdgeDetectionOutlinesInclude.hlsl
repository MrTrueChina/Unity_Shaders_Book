// 只加载一次的写法，没有加载记录时才加载，加载立刻写加载记录
#ifndef SOBELOUTLINES_INCLUDED
#define SOBELOUTLINES_INCLUDED

/// Sobel 边缘检测
///
/// 使用 Sobel 算子进行边缘检测
/// Sobel 算子是如下的矩阵
/// -1 0 1
/// -2 0 2
/// -1 0 1
///
/// 其原理是卷积运算，以深度检测为例：
///
/// 假设一个监测点和周围的深度都是 0.5，则卷积结果是
/// (-0.5 + 0 + 0.5) + (-1 + 0 + 1) + (-0.5 + 0 + 0.5) = 0
///
/// 而如果一个监测点左侧深度是 1，右侧深度是 0，则卷积结果是
/// (-1 + 0 + 0) + (-2 + 0 + 0) + (-1 + 0 + 0) = -4
///
/// 由此可以发现这个算子计算后的绝对值越大则两侧的数值差越大
/// 因此这个算子可以用于计算横向的数值突变，而一般来说连续的面上数值不会产生太大的突变，而不连续的边缘则容易产生数值突变，由此就实现了边缘检测
///
/// 当然边缘检测不是只有水平方向，因此还需要一个旋转 90 度的矩阵作为垂直方向的算子
/// 而如果将两个算子以绝对值叠加就会发现周围八个点的值都是 2，这样就避免了各方向权重不均匀，因此这个矩阵是 1-2-1 而不是 1-1-1 或 2-2-2


// Sobel 边缘检测的监测点的坐标偏移量数组，相对于监测点
// 实际上就是以监测点为中心往外扩增一圈形成九宫格
static float2 sobelSimplePoints[9] = {
    float2(-1, 1), float2(0, 1), float2(1, 1),
    float2(-1, 0), float2(0, 0), float2(1, 0),
    float2(-1, -1), float2(0, -1), float2(1, -1)
};

// Sobel 边缘检测的X方向的算子
static float sobelXMatrix[9] = {
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
};

// Sobel 边缘检测的Y方向的算子
static float sobelYMatrix[9] = {
    1, 2, 1,
    0, 0, 0,
    -1, -2, -1
};

void DepthSobel_float(float2 UV, float Thickness, out float Out) {
    float2 sobel = 0;

    [unroll] for(int i = 0; i < 9; i++){
        // 卷积的一步，原理是取出这一步的 UV 偏移量乘上步长得到这个采样点在深度图上的 UV，然后使用 URP 提供的宏取出这个位置的深度
        float depth = SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV + sobelSimplePoints[i] * Thickness);
        // 确认深度后一次对两个算子矩阵进行运算，分别存入到 float2 的两个值里
        sobel += depth * float2(sobelXMatrix[i], sobelYMatrix[i]);
    }

    // 因为卷积把 XY 两个轴的检测一起存起来了，这里可以直接取向量长度，长度不会是负数能省下来取绝对值的计算量
    // 但是相对的，取长度本身的计算量也不低
    Out = length(sobel);
}

#endif