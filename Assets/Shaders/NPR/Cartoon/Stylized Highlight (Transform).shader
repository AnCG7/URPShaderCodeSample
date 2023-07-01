

//参考论文
//论文1：Anjyo K I , Hiramitsu K .Stylized Highlights for Cartoon Rendering and Animation[J].Computer Graphics & Applications IEEE, 2003, 23(4):54-61.DOI:10.1109/MCG.2003.1210865. 

//论文2: 苏延辉,韦欢,费广正,等.卡通高光的风格化算法及其实现[C]//中国计算机图形学大会.2006.


//代码几乎是根据 论文1 和 NPR_Lab(看下面的链接) 写的，主要思想是在切线空间变换Blinn高光计算中的半程向量H，以此来调整H和法线的关系，使其表现发生变化
//使其表现出来：平移，旋转，缩放，分割，方块化 的效果，这些效果是可以组合的在一起的
//论文2 中有一个关于 方块化 实现的稍微修改，所以我也记录了进来

//因为是在切线空间，所以可能需要注意一下切线的平滑程度

//其他参考：
//https://github.com/candycat1992/NPR_Lab
//https://blog.csdn.net/candycat1992/article/details/50167285

Shader "Lakehani/URP/NPR/Cartoon/Stylized Highlight Transform"
{

    Properties
    {
        //关于属性的默认特性Header、枚举、Space等参考 https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html
        [Header(Base)][Space(5)]
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
       	_SpecularScale ("Specular Scale", Range(0, 0.05)) = 0.015

        [Header(Translation)][Space(5)]
		_TranslationX ("Translation X", Range(-1, 1)) = 0
		_TranslationY ("Translation Y", Range(-1, 1)) = 0

        [Header(Rotation)][Space(5)]
		_DegreeX ("Degree X", Range(-180, 180)) = 0
		_DegreeY ("Degree Y", Range(-180, 180)) = 0
		_DegreeZ ("Degree Z", Range(-180, 180)) = 0

        [Header(Directional Scale)][Space(5)]
		_DirectionalScaleX ("Directional Scale X", Range(-1, 1)) = 0
		_DirectionalScaleY ("Directional Scale Y", Range(-1, 1)) = 0

        [Header(Split)][Space(5)]
		_SplitX ("Split X", Range(0, 1)) = 0
		_SplitY ("Split Y", Range(0, 1)) = 0

        [Header(Square)][Space(5)]
        _SquareOffsetX("Square OffsetX",Range(-1, 1)) = 1
        _SquareOffsetY("Square OffsetY", Range(-1, 1)) = 1
        _SquareN ("Square N",Range(1, 10)) = 1
		_SquareScale ("Square Scale", Range(0, 1)) = 0
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS     : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalTS : TEXCOORD0;
                float3 viewTS : TEXCOORD1;
                float3 lightDirTS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _SpecularColor;
            half _SpecularScale;
			half _TranslationX;
			half _TranslationY;
            half _DirectionalScaleX;
			half _DirectionalScaleY;
			half _DegreeX;
			half _DegreeY;
			half _DegreeZ;
			half _SplitX;
			half _SplitY;
            half _SquareOffsetX;
            half _SquareOffsetY;
            half _SquareN;
			half _SquareScale;
            CBUFFER_END



            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                //转到切线空间
                float3x3 TBNWorld = float3x3(normalInput.tangentWS.xyz, normalInput.bitangentWS.xyz, normalInput.normalWS.xyz);
                OUT.normalTS = TransformWorldToTangent(normalInput.normalWS,TBNWorld);
                OUT.viewTS = TransformWorldToTangent(GetWorldSpaceViewDir(positionWS),TBNWorld);
                OUT.lightDirTS = TransformWorldToTangent(GetMainLight().direction,TBNWorld);

                return OUT;
            }

            //Translation 偏移：在切线空间中沿x和y偏移
            half3 StylizedHighlightTranslation(half3 halfDirTS,half translationX,half translationY)
            {
                halfDirTS = halfDirTS + half3(translationX, translationY, 0);
			    halfDirTS = normalize(halfDirTS);
                return halfDirTS;
            }

            //Directional Scale 方向缩放：在切线空间通过使H向量更加接近和远离法线来实现缩放，如果X和Y不相等会拉长或压扁高光
            half3 StylizedHighlightDirectionalScale(half3 halfDirTS,half scaleX, half scaleY)
            {
                halfDirTS = halfDirTS - scaleX * halfDirTS.x * half3(1, 0, 0);
				halfDirTS = normalize(halfDirTS);
				halfDirTS = halfDirTS - scaleY * halfDirTS.y * half3(0, 1, 0);
				halfDirTS = normalize(halfDirTS);
                return halfDirTS;
            }

            //Rotation 旋转：在切线空间中旋转，XYZ对应TBN（TBN切线空间3轴，不在赘述），直接旋转X和Y的话效果类似偏移，但是当高光拉长或压扁或分裂后调整Z可以绕法线旋转
            //如果旋转矩阵不知道怎么写，可以参考 Shader Graph 的 Rotate About Axis Node 对应的函数是 Unity_RotateAboutAxis_Degrees 可以在 Shader Graph 的文档中找到
            //这里degree指传入的是角度不是弧度
            half3 StylizedHighlightRotation(half3 halfDirTS,half degreeX,half degreeY,half degreeZ)
            {
                //NPR_Lab中的写法也是正确的如下，但是由于sin和默认旋转是相反的，所以编辑器中调整滑杆方向时，高光偏移和Unity_RotateAboutAxis_Degrees也是反的
                //float xRad = radians(degreeX);
				//float3x3 xRotation = float3x3(1, 0, 0,
				//									 0, cos(xRad), sin(xRad),
				//									 0, -sin(xRad), cos(xRad));
				//float yRad = radians(degreeY);
				//float3x3 yRotation = float3x3(cos(yRad), 0, -sin(yRad),
				//									 0, 1, 0,
				//									 sin(yRad), 0, cos(yRad));
				//float zRad = radians(degreeZ);
				//float3x3 zRotation = float3x3(cos(zRad), sin(zRad), 0,
				//									 -sin(zRad), cos(zRad), 0,
				//									 0, 0, 1);								
				//halfDirTS = mul(zRotation, mul(yRotation, mul(xRotation, halfDirTS)));

                //这里我用化简后的Unity_RotateAboutAxis_Degrees内容，和上面比注意看sin的正负号
                float xRad = radians(degreeX);
                float3x3 xRotation = float3x3(1, 0, 0,
											  0, cos(xRad), -sin(xRad),
											  0, sin(xRad), cos(xRad));
                float yRad = radians(degreeY);
                float3x3 yRotation = float3x3(cos(yRad), 0, sin(yRad),
											  0, 1, 0,
											  -sin(yRad), 0, cos(yRad));
                float zRad = radians(degreeZ);
                float3x3 zRotation = float3x3(cos(zRad), -sin(zRad), 0,
											  sin(zRad), cos(zRad), 0,
											  0, 0, 1);
                halfDirTS = mul(zRotation, mul(yRotation, mul(xRotation, halfDirTS)));
                halfDirTS = normalize(halfDirTS);
                return halfDirTS;
            }

            //Split 分割：根据sign在X和Y上分不同方向远离法线，全部分离开可以分割为4个
            half3 StylizedHighlightSplit(half3 halfDirTS,half splitX,half splitY)
            {
                half signX = 1;
				if (halfDirTS.x < 0) {
					signX = -1;
				}
				half signY = 1;
				if (halfDirTS.y < 0) {
					signY = -1;
				}
				halfDirTS = halfDirTS - splitX * signX * half3(1, 0, 0) - splitY * signY * half3(0, 1, 0);
				halfDirTS = normalize(halfDirTS);
                return halfDirTS;
            }

            //Square 方块化：控制高光变成方形的程度，不适当的值会出现很奇怪的效果
            //论文中的描述翻译过来是：给定一个整数squareN(实际上浮点数更好使)和一个正数squareScale范围[0.0,1.0]。这样，高亮区域将会在du和dv轴上呈现方形形状。(du和dv就是x和y)
            //通过旋转操作，我们可以使高亮区域朝着所需的方向形成方形。当squareN值较大时，区域会变得更加锐利，而squareScale定义了方形区域的大小。
            half3 StylizedHighlightSquare(half3 halfDirTS,half offsetX,half offsetY,half squareN,half squareScale)
            {
                //这是论文中的实现，这里我调了非常久怎么调也不对，记录一下：squareN论文里写的是integer（整数）,但是将squareN = floor(squareN)变为整数几乎无法调出方形
                //du和dv是指在这个轴向上，所以当我们指定du(1,0,0)和dv(0,1,0)时你会发现有一边是方的，另一边还是很圆
                //这里可以把du和dv的归一化去掉，会有一些其他的效果
                float3 du = normalize(float3(offsetX,0,0));
                float3 dv = normalize(float3(0,offsetY,0));
                float theta = min(acos(dot(halfDirTS, du)), acos(dot(halfDirTS,dv)));
                float sqrnorm = sin(pow(2 * theta,squareN));
                halfDirTS = halfDirTS - squareScale * sqrnorm * (dot(halfDirTS, du) * du + dot(halfDirTS, dv) * dv);
                halfDirTS = normalize(halfDirTS);
                return halfDirTS;
            }

            //Square 方块化：控制高光编成方形的程度，不适当的值会出现很奇怪的效果
            //论文2 中描述的关于改进的实现方式，使矩形效果更明显
            half3 StylizedHighlightImproveSquare(half3 halfDirTS,half offsetX,half offsetY,half squareN,half squareScale)
            {
                float3 du = normalize(float3(offsetX,0,0));
                float3 dv = normalize(float3(0,offsetY,0));
                float theta = min(cos(dot(halfDirTS, du)), cos(dot(halfDirTS,dv)));
                float sqrnorm = cos(pow(4 * theta,squareN));
                halfDirTS = halfDirTS - squareScale * sqrnorm * (dot(halfDirTS, du) * du + dot(halfDirTS, dv) * dv);
                halfDirTS = normalize(halfDirTS);
                return halfDirTS;
            }

            //合在一起的，方便观察和尝试
            half3 StylizedHighlightCombinationSquare(half3 halfDirTS,half offsetX,half offsetY,half squareN,half squareScale)
            {
                //这是NPR_Lab的实现，其作者的描述是：按照公式计算，总是无法调整得到希望的方块形，所以稍微更改了下，不计算两个角度的最小值，而是同时使用两个角度
                //float sqrThetaX = acos(halfDirTS.x);
				//float sqrThetaY = acos(halfDirTS.y);
				//half sqrnormX = sin(pow(2 * sqrThetaX, squareN));
				//half sqrnormY = sin(pow(2 * sqrThetaY, squareN));
				//halfDirTS = halfDirTS - squareScale * (sqrnormX * halfDirTS.x * half3(1, 0, 0) + sqrnormY * halfDirTS.y * half3(0, 1, 0));
				//halfDirTS = normalize(halfDirTS);

                //这里我使用了2次，2个完全相反的轴向，来使整体看起来是个方形，如果只用一次会发现有一边是方的，另一边还是很圆
                //当然你也可以只用一次看看是不是你想要的
                halfDirTS = StylizedHighlightSquare(halfDirTS,offsetX,offsetY,squareN,squareScale);
                halfDirTS = StylizedHighlightSquare(halfDirTS,-offsetX,-offsetY,squareN,squareScale);

                //论文2 实现的调用，使矩形效果更明显
                //halfDirTS = StylizedHighlightImproveSquare(halfDirTS,offsetX,offsetY,squareN,squareScale);
                
                return halfDirTS;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalTS = normalize(IN.normalTS);
				half3 lightDirTS = normalize(IN.lightDirTS);
				half3 viewTS = normalize(IN.viewTS);
				half3 halfDirTS = normalize(viewTS + lightDirTS);
                //NPR_Lab的描述中，通常实现顺序是：缩放，旋转，平移，分割，方块化
                //但是当我调整过Translation后，再调整Rotation的_DegreeZ会有奇怪的感觉
                //所以我这里根据论文介绍公式的顺序：平移，旋转，缩放，分割，方块化
                //不一样的顺序会导致结果不一样
                
                //Translation
                halfDirTS = StylizedHighlightTranslation(halfDirTS,_TranslationX,_TranslationY);
                //Rotation
                halfDirTS = StylizedHighlightRotation(halfDirTS,_DegreeX,_DegreeY,_DegreeZ);
                //Directional Scale
                halfDirTS = StylizedHighlightDirectionalScale(halfDirTS,_DirectionalScaleX,_DirectionalScaleY);      
                //Split
                halfDirTS = StylizedHighlightSplit(halfDirTS,_SplitX,_SplitY);
                //Square
                halfDirTS = StylizedHighlightCombinationSquare(halfDirTS,_SquareOffsetX,_SquareOffsetY,_SquareN,_SquareScale);

                //计算高光
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half spec = dot(normalTS, halfDirTS);

                //卡通高光，拉近拉远自适应高光边缘抗锯齿，具体参见shader文件 Cel-Shading (Procedural) 中的【标记B】
				half w = fwidth(spec) * 1.0;
				half3 specularColor = lerp(half3(0, 0, 0), lightColor * _SpecularColor.rgb, smoothstep(-w, w, spec + _SpecularScale - 1));

                half4 totalColor = half4(specularColor.rgb,1);
                return totalColor;
            }

            ENDHLSL
        }
    }
}
