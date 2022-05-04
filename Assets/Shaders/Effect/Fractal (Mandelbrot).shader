/*
分形是一个非常有趣的东西，也有很多酷炫的效果
Shader演示的是Mandelbrot集合
注意：因为Float的精度问题所以当放大过大时会出现像素化的问题，如果一定要解决的话可以用2个float模拟更高的精度

常见
Mandelbrot集合
Julia集合
Cantor集合
Newton分形
Nova分形
等等
参考：
https://en.wikipedia.org/wiki/Fractal
*/

Shader "Lakehani/URP/Effect/Fractal (Mandelbrot)"
{
    Properties
    {
        [NoScaleOffset]_RampMap("Ramp Map", 2D) = "white" {}
        _RampMapColor("Ramp Map Color", Color) = (1,1,1,1)
        _InitX("InitX",Float) = -0.7452
        _InitY("InitY",Float) = 0.186
        _Zoom("Zoom",Range(0.2,1.2)) = 1.2 //再大会失真，可以把范围改改看
        _Speed("Speed",Range(0,1)) = 0.3
        _MaxIterations("Max Iterations",Float) = 256
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _RampMapColor;
            float _InitX;
            float _InitY;
            float _Zoom;
            int _MaxIterations;
            float _Speed;
            CBUFFER_END
            TEXTURE2D(_RampMap);
            SAMPLER(sampler_RampMap);


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            //f(z) = z^2+c
            float2 mandblot(float2 z,float2 c){
                return float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
            }

            float mandelblotSet(float2 c,int maxIterations){
                float2 z = float2(0,0);
                int i = 0;
                for(; i < maxIterations ; ++i)
                {   
                   z = mandblot(z,c);
                   if(z.x * z.x + z.y * z.y > 4.0) //半径大于2，不属于集合
                     break;
                }
                return (float)i / maxIterations;
            }


            float4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv + float2(-0.5,-0.5);//为能放到中间
                //这一串计算是我为了方便动画缩放效果，设定的特殊值
                float zoom = pow(0.0015,(1 + cos(_Speed * _Time.y + PI))* 0.5 * _Zoom - 0.2);
                //可以根据Mandelbrot集合的资料修改这个c的初始常量值
                float2 c = float2(_InitX,_InitY) + uv * zoom;
                float iter = mandelblotSet(c,_MaxIterations);
                float4 col = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap,float2(iter,1)) * _RampMapColor;
                return col;
            }
            ENDHLSL
        }
    }
}
