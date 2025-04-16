/*
 * 负责贴花投影器的数据部分的添加更新和移除操作，以及一些公共的方法
 */
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class SimpleDecalDataManager
{
    public class DecalData
    {
        public Material material;
        public float clipAngleThreshold;//贴花的裁剪角度
        public float decalScale;//贴花的缩放
        public uint renderingLayerMask; //只有设定的层才会被贴花
        public Vector3 clipBoxLocalMin; //局部空间的clip范围包含轴点
        public Vector3 clipBoxLoaclMax; //局部空间的clip范围包含轴点
        public Matrix4x4 worldToLocalMatrix;//从世界空间转换到局部空间的矩阵
        public Vector3 projectionDir;//世界空间投影方向
        public Matrix4x4 normalToWorldMatrix; //TBN转换矩阵，用于将法线从切线空间转换到世界空间
        public SimpleDecalProjector projector; //用于记录对应的SimpleDecalProjector
        public MaterialPropertyBlock materialPropertyBlock;
        public BoundingSphere worldBoundingSphere; //包围球后面做剔除用
        public Mesh projectorMesh; //使用一个cube作为贴花的mesh，后面用drawMesh绘制，而不是用一个全屏的quad
        public Matrix4x4 projectorMeshMatrix;//从局部空间转换为世界空间的矩阵
        public int drawOrder;//用于排序,调整贴花叠加顺序
    }
    private static Mesh s_decalProjectorMesh;
    private static MaterialPropertyBlock s_materialPropertyBlock = new MaterialPropertyBlock();
    private static Dictionary<SimpleDecalProjector,DecalData> s_decalDataMap = new Dictionary<SimpleDecalProjector, DecalData>();
    public static IReadOnlyDictionary<SimpleDecalProjector,DecalData> decalDataMap
    {
        get { return s_decalDataMap; }
    }
    public static void AddDecaProjector(SimpleDecalProjector decalProjector)
    {
        if (decalProjector == null) return;
        DecalData decalData = null;
        if (!s_decalDataMap.ContainsKey(decalProjector))
        {
            decalData = new DecalData();
            s_decalDataMap.Add(decalProjector,decalData);
        }
        UpdateDecalData(decalProjector,decalData);
    }


    private static Mesh GetDecalBoxMesh()
    {
        if (s_decalProjectorMesh == null)
            s_decalProjectorMesh = CoreUtils.CreateCubeMesh(new Vector4(-0.5f, -0.5f, -0.5f, 1.0f), new Vector4(0.5f, 0.5f, 0.5f, 1.0f));
        return s_decalProjectorMesh;
    }

    public static void RemoveDecalProjector(SimpleDecalProjector decalProjector)
    {
        if (decalProjector == null) return;
        if (s_decalDataMap.ContainsKey(decalProjector))
        {
            s_decalDataMap.Remove(decalProjector);
        }
    }
    
    public static void UpdateDecalProjector(SimpleDecalProjector decalProjector)
    {
        if (decalProjector == null) return;
        if (s_decalDataMap.ContainsKey(decalProjector))
        {
            var decalData = s_decalDataMap[decalProjector];
            if (decalData != null)
            {
                UpdateDecalData(decalProjector,decalData);   
            }
        }
    }
    
    private static void UpdateDecalData(SimpleDecalProjector decalProjector,DecalData decalData)
    {
        if (decalProjector == null) return;
        if (decalData == null) return;
        decalData.material = decalProjector.decalMaterial;
        decalData.clipAngleThreshold = decalProjector.degreeThreshold * Mathf.Deg2Rad;
        decalData.decalScale = decalProjector.decalScale;
        decalData.renderingLayerMask = decalProjector.renderingLayerMask;
        decalData.projectionDir = decalProjector.transform.forward;
        
        var offset = Vector3.Scale(decalProjector.boxSize,-decalProjector.pivot);
        var pos =  decalProjector.transform.position;
        var rot = decalProjector.transform.rotation;
        var scale = Vector3.one;
        decalData.clipBoxLocalMin = -decalProjector.boxSize * 0.5f + offset; //从中心开始偏移轴点，因为原点在中心
        decalData.clipBoxLoaclMax = decalProjector.boxSize * 0.5f + offset;  //从中心开始偏移轴点，因为原点在中心
        var localToWorld = Matrix4x4.TRS(pos, rot, scale);
        decalData.worldToLocalMatrix = localToWorld.inverse;
        
        // 计算法线从切线空间到世界空间的转换矩阵，因为我们的法线是切线空间的，因为box的投影方式是平行于box的平面的
        //想象在一个平面上显示贴图，我们可以定义这个平面的中切线空间3轴，N是投影方向的反方向，以此来定制切线空间到世界空间的转换矩阵
        Matrix4x4 decalRotation = localToWorld;
        var flipZ = Matrix4x4.Scale(new Vector3(1f,1f,-1f));
        decalData.normalToWorldMatrix = decalRotation * flipZ;

        //因为mesh是一个标准cube,后面我需要绘制一个和投影用的虚拟box一样的cube覆盖渲染的区域
        //全屏quad有个问题就是，如果贴花距离很远，像素屏占比很低，但是quad却全覆盖了屏幕
        Matrix4x4 projectorMeshMatrix = localToWorld;
        var projectorMeshScale = Matrix4x4.Scale(decalProjector.boxSize);
        var projectorMeshOffset = Matrix4x4.Translate(offset);
        
        decalData.projectorMeshMatrix = projectorMeshMatrix * projectorMeshOffset * projectorMeshScale;
        decalData.projectorMesh = GetDecalBoxMesh();
        decalData.projector = decalProjector;
        
        if (decalData.materialPropertyBlock == null)
        {
            decalData.materialPropertyBlock = s_materialPropertyBlock;
        }
        GetDecalWorldBoundingSphere(decalData.clipBoxLocalMin,decalData.clipBoxLoaclMax,localToWorld,ref decalData.worldBoundingSphere);
    
        decalData.drawOrder = decalProjector.drawOrder;
        
    }
    
    public static void UpdateMaterialProperty(SimpleDecalDataManager.DecalData decalData)
    {
        if (decalData == null)return;
        var mat  = decalData.material;
        if (mat == null) return; 
        var matPropBlock = decalData.materialPropertyBlock;
        if (matPropBlock == null) return;
        matPropBlock.SetFloat("_DecalRenderingLayerMask", decalData.renderingLayerMask);
        matPropBlock.SetFloat("_ClipAngleThreshold", decalData.clipAngleThreshold);
        matPropBlock.SetFloat("_DecalScale", decalData.decalScale);
        matPropBlock.SetMatrix("_DecalWToLMatrix", decalData.worldToLocalMatrix);
        matPropBlock.SetVector("_ProjectionDir", decalData.projectionDir);
        matPropBlock.SetVector("_ClipBoxLocalMin", decalData.clipBoxLocalMin);
        matPropBlock.SetVector("_ClipBoxLocalMax", decalData.clipBoxLoaclMax);
        matPropBlock.SetMatrix("_NormalToWorldMatrix", decalData.normalToWorldMatrix);
    }
    
    private static void GetDecalWorldBoundingSphere(Vector3 clipBoxLocalMin,Vector3 clipBoxLocalMax,Matrix4x4 localToWorldMatrix,ref BoundingSphere bounds)
    {
        // 计算世界空间的球形包围盒
        Vector3 worldCenter = localToWorldMatrix.MultiplyPoint((clipBoxLocalMin + clipBoxLocalMax) * 0.5f);
        Vector3 worldHalfExtents = localToWorldMatrix.MultiplyVector((clipBoxLocalMax - clipBoxLocalMin) * 0.5f);
        float radius = worldHalfExtents.magnitude;
        bounds.position = worldCenter;
        bounds.radius = radius;
    }

    public static void GetCullingAndSortedDecalList(ref List<DecalData> decalDataList)
    {
        CullingDecalList(ref decalDataList);
        SortDecalList(ref decalDataList);
    }

    public static void CullingDecalList(ref List<DecalData> decalDataList)
    {
        if (decalDataList == null)
        {
            decalDataList = new List<DecalData>();
        }
        else
        {
            decalDataList.Clear();
        }
        //这个部分可以使用Unity自己的CullingGroup来做，但是需要自己实现CullingGroup的回调函数，这里为了简单，就不使用CullingGroup了
        // 遍历所有贴花，判断是否在视锥范围内
        // 获取主摄像机视锥平面
        var camera = Camera.main;
        if (camera == null) return;
        Plane[] planes = GeometryUtility.CalculateFrustumPlanes(camera);
        foreach (var decalData in s_decalDataMap.Values)
        {
            if (decalData == null) continue;
            if (decalData.material == null) continue;
            var boundsSphere = decalData.worldBoundingSphere;
            // 创建包围球（半径取最大轴长）
            float radius = boundsSphere.radius;
            Vector3 worldCenter = boundsSphere.position;
            // 视锥剔除测试
            bool isVisible = true;
            foreach (Plane plane in planes)
            {
                if (plane.GetDistanceToPoint(worldCenter) < -radius)
                {
                    isVisible = false;
                    break;
                }
            }
            if (isVisible)
            {
                decalDataList.Add(decalData);
            }
        }
    }
    public static void SortDecalList(ref List<DecalData> decalDataList)
    {
        if (decalDataList == null) return;
        // 按照drawOrder进行排序
        decalDataList.Sort((a, b) => a.drawOrder.CompareTo(b.drawOrder));
    }

    public static void Clear()
    {
        s_decalDataMap.Clear();
    }
}
