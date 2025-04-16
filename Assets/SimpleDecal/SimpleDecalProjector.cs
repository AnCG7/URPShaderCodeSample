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