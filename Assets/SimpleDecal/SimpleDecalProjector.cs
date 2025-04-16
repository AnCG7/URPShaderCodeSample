/*
    * 内容概述:
    * SimpleDecal 是一个基于 Unity 通用渲染管线 (URP) 实现的贴花系统。该系统允许用户在场景中添加贴花，
    * 并通过贴花投影器 (SimpleDecalProjector) 控制贴花的各种属性，如材质、大小、角度阈值、绘制顺序等。
    * 贴花材质可以包含反照率纹理、法线贴图等，用于增强场景的视觉效果。
    * 
    * 工作原理:
    * - 贴花投影器 (SimpleDecalProjector) 作为 MonoBehaviour 组件挂载在游戏对象上，管理贴花的属性。
    * - 当贴花投影器启用或属性发生变化时，会调用 SimpleDecalDataManager 中的方法来更新贴花数据。
    * - 渲染过程中，使用特定的的着色器对贴花进行渲染。
    * - 并利用利用 RenderingLayerMask 对渲染层进行裁剪，确保贴花只在指定的层上渲染
    * 
    * 主要组件和类:
    * - SimpleDecalProjector: 管理贴花的属性和状态，处理属性变化事件。
    * - SimpleDecalDataManager: 负责贴花投影器的添加、更新和移除操作。
    * - SimpleDecalRendererFeature: 自定义渲染功能，处理贴花的渲染过程。
    * - SimpleDecalPrepass: 此shader处理贴花的预渲染过程预渲染主要是为了拿到RenderingLayerMask的数据，用于根据物体和贴花的RenderingLayerMask做裁剪
    * - SimpleDecal: 此shader利用屏幕空间的法线缓冲、深度缓冲、RenderingLayerMask的缓冲以及角度阈值来做裁剪和具体内容渲染
    * -
    * 特殊说明:
    * - Unity已经有内置的URPDecalProjector，但是为了学习贴花的原理，所以自己实现了一个屏幕空间的贴花系统
    * - 其中部分参考了URPDecalProjector的相关实现，但是由于URPDecalProjector牵扯了结构和性能优化较为复杂，不方便入门学习
    * - 绘制一个Cube Mesh在虚拟的投影box且与投影box大小方向一致，用于贴花的投影的范围
    * - 此示例因为发现部分该版本URP的API没有开放，部分地方利用了反射获取需要的数据
    * - RenderingLayerMask对应的缓冲由SimpleDecalPrerenderPass生成，为了更好的理解他怎么做的，没有使用unity内置的
    * - 为了方便入门参考，没有进行过量优化，主要是为了方便学习流程，而不是工程直接使用
*/

using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Serialization;

[ExecuteAlways]

public class SimpleDecalProjector : MonoBehaviour
{
    [SerializeField]
    private Material _decalMaterial;
    private Material _lastDecalMaterial;
    public Material decalMaterial
    {
        get { return _decalMaterial;}
        set
        {
            _lastDecalMaterial = _decalMaterial;
            _decalMaterial = value;
            if (_decalMaterial != null)
            {
                //上一次材质为空，现在不为空且在启用时状态时添加
                if (isActiveAndEnabled)
                {
                    if (_lastDecalMaterial == null)
                    {
                        SimpleDecalDataManager.AddDecaProjector(this);
                    }
                }
                OnValidate();
            }
            else
            {
                //材质为空且启用时状态时移除
                if (isActiveAndEnabled)
                {
                    SimpleDecalDataManager.RemoveDecalProjector(this);
                }
            }
        }
    }
    [SerializeField,Range(0f, 90f)]
    private float _degreeThreshold = 75f;
    public float degreeThreshold
    {
        get { return _degreeThreshold; }
        set { _degreeThreshold = value; OnValidate(); }
    }
    [SerializeField]
    private float _decalScale = 1f;
    public float decalScale
    {
        get { return _decalScale; }
        set { _decalScale = value; OnValidate(); }
    }
    [SerializeField]
    private Vector3 _boxSize = new Vector3(1f, 1f, 1f); //作为贴花范围的 box 大小
    public Vector3 boxSize
    {
        get { return _boxSize; }
        set { _boxSize = value; OnValidate(); }
    }
    [SerializeField, Range(0f, 100f)]
    private int _drawOrder = 0;
    public int drawOrder
    {
        get { return _drawOrder; }
        set { _drawOrder = value; OnValidate(); }
    }
    [SerializeField]
    private uint _renderingLayerMask = 1;
    public uint renderingLayerMask
    {
        get { return _renderingLayerMask; }
        set { _renderingLayerMask = value; OnValidate(); }
    }
    
    private Vector3 _pivot = new Vector3(0f, 0f, -0.5f);//box默认轴点在中心，我们设计的box轴点在面上，所以要偏移
    public Vector3 pivot
    {
        get { return _pivot; }
    }
    
    private Vector3 _lastPosition;
    private Quaternion _lastRotation;

    private void Awake()
    {
        _lastDecalMaterial = _decalMaterial;
    }

    private void OnEnable()
    {
        if (_decalMaterial != null)
        {
            SimpleDecalDataManager.AddDecaProjector(this);
        }
    }
    
    private void OnDisable()
    {
        SimpleDecalDataManager.RemoveDecalProjector(this);
    }
    
    private void OnValidate()
    {
        if (!isActiveAndEnabled)
            return;
        SimpleDecalDataManager.UpdateDecalProjector(this);
    }
    
    private void LateUpdate()
    {
        // 检查 transform 是否发生变化
        if (transform.position != _lastPosition || 
            transform.rotation != _lastRotation)
        {
            OnValidate();
            _lastPosition = transform.position;
            _lastRotation = transform.rotation;
        }
    }
    public bool IsValidMaterial()
    {
        if (_decalMaterial == null)
            return false;

        if (_decalMaterial.FindPass("SimpleDecalPass") != -1)
            return true;
        
        return false;
    }
}