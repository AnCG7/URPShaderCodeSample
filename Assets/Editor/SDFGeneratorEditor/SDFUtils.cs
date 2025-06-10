//参考：
//http://www.codersnotes.com/notes/signed-distance-fields/
//https://github.com/Lisapple/8SSEDT
//https://github.com/Alunice/TaTa/tree/master/SDF
//https://github.com/xudxud/Unity-SDF-Generator

using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

namespace SDFGenerator2D
{
	public class SDFUtils
	{
		internal class TexturePointValue
		{
			internal int width { get; private set; }
			internal int height { get; private set; }
			internal float[,] grid = new float[0, 0];
			internal TexturePointValue()
			{
			}

			internal void Resize(int width, int height)
			{
				if (this.width != width || this.height != height)
				{
					this.width = width;
					this.height = height;
					grid = new float[height, width];
				}
			}
			public override string ToString()
			{
				StringBuilder builder = new StringBuilder();
				for (int y = 0; y < height; y++)
				{
					for (int x = 0; x < width; x++)
					{
						float pointValue = grid[y, x];
						builder.Append(pointValue.ToString());
						builder.Append(" , ");
					}
					builder.Remove(builder.Length - 3, 3);
					builder.AppendLine();
				}
				return builder.ToString();
			}
		}

		internal static float GetColorValue(ref Color color, EColorChannel channel)
		{
			return color[(int)channel];
		}

		internal static void SetColorValue(ref Color color, float value, EColorChannel channel)
		{
			color[(int)channel] = value;
		}

		/// <summary>
		/// 这里简单的根据比例舍弃中间的像素信息达到映射到小图片的目的
		/// </summary>
		internal static void WriteTexture(TexturePointValue srcTextureData, Texture2D targetTexture, EColorChannel targetChannel = EColorChannel.A)
		{
			int srcWidth = srcTextureData.width;
			int srcHeight = srcTextureData.height;
			int targetWidth = targetTexture.width;
			int targetHeight = targetTexture.height;
			//只能往小了缩,往大了放Nothing没有意义
			if (targetWidth > srcWidth)
			{
				targetWidth = srcWidth;
			}
			if (targetHeight > srcHeight)
			{
				targetHeight = srcHeight;
			}

			float scaleX = srcWidth / targetWidth;
			float scaleY = srcHeight / targetHeight;
			for (int y = 0; y < targetHeight; y++)
			{
				for (int x = 0; x < targetWidth; x++)
				{
					//简单丢弃中间的像素
					float finalVaule = srcTextureData.grid[(int)(x * scaleX), (int)(y * scaleY)];
					float final = Mathf.Clamp01(finalVaule);

					Color color = Color.black;
					SetColorValue(ref color, final, targetChannel);
					targetTexture.SetPixel(x, y, color);
				}
			}
		}

		/// <summary>
		/// 这里简单的根据比例舍弃中间的像素信息达到映射到小图片的目的
		/// </summary>
		internal static void WriteTexture(Texture2D srcTexture, Texture2D targetTexture, EColorChannel srcChannel = EColorChannel.A, EColorChannel targetChannel = EColorChannel.A)
		{
			int srcWidth = srcTexture.width;
			int srcHeight = srcTexture.height;
			int targetWidth = targetTexture.width;
			int targetHeight = targetTexture.height;
			//只能往小了缩,往大了放Nothing没有意义
			if (targetWidth > srcWidth)
			{
				targetWidth = srcWidth;
			}
			if (targetHeight > srcHeight)
			{
				targetHeight = srcHeight;
			}

			float scaleX = srcWidth / targetWidth;
			float scaleY = srcHeight / targetHeight;
			for (int y = 0; y < targetHeight; y++)
			{
				for (int x = 0; x < targetWidth; x++)
				{
					//简单丢弃中间的像素
					Color srcColor = srcTexture.GetPixel((int)(x * scaleX), (int)(y * scaleY));
					float finalVaule = GetColorValue(ref srcColor, srcChannel);
					float final = Mathf.Clamp01(finalVaule);

					Color color = Color.black;
					SetColorValue(ref color, final, targetChannel);
					targetTexture.SetPixel(x, y, color);
				}
			}
		}

		internal static void WriteTexture(RenderTexture srcTexture, Texture2D targetTexture,
			EColorChannel srcChannel = EColorChannel.A, EColorChannel targetChannel = EColorChannel.A)
		{
			var tex2D = RenderTextureToTexture2D(srcTexture);
			WriteTexture(tex2D,targetTexture, srcChannel, targetChannel);
		}

		internal static Texture2D RenderTextureToTexture2D(RenderTexture rt)
		{
			if (rt == null) return null;
    
			// 将 RenderTextureFormat 转换为 GraphicsFormat
			GraphicsFormat graphicsFormat = GraphicsFormatUtility.GetGraphicsFormat(rt.format, false);
    
			// 创建目标 Texture2D（需与 RenderTexture 分辨率一致）
			Texture2D tex = new Texture2D(rt.width, rt.height, graphicsFormat, TextureCreationFlags.None);
    
			// 临时保存当前渲染目标
			RenderTexture currentActive = RenderTexture.active;
    
			try
			{
				// 设置 RenderTexture 为当前渲染目标
				RenderTexture.active = rt;
    
				// 读取像素数据（从 RenderTexture 读取到 Texture2D）
				tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
				tex.Apply();
			}
			finally
			{
				// 恢复原渲染目标，避免影响后续渲染
				if (currentActive != null)
					RenderTexture.active = currentActive;
			}
    
			return tex;
		}
	}
}
