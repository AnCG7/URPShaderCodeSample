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
using static SDFGenerator2D.SDFUtils;

namespace SDFGenerator2D
{
	public class SDF8ssedt
	{
		private struct Point
		{
			public int dx, dy;
			public Point(int dx, int dy)
			{
				this.dx = dx;
				this.dy = dy;
			}
			public double DistSq() { return dx * dx + dy * dy; }
		}
		private class Grid
		{
			public int width, height;
			public Point[,] grid = new Point[0, 0];
			public Grid()
			{
			}
			public void Resize(int width, int height)
			{
				if (this.width != width || this.height != height)
				{
					this.width = width;
					this.height = height;
					grid = new Point[height, width];
				}
			}
			public override string ToString()
			{
				StringBuilder builder = new StringBuilder();
				for (int y = 0; y < height; y++)
				{
					for (int x = 0; x < width; x++)
					{
						Point point = grid[y, x];
						builder.Append(math.sqrt(point.DistSq()));
						builder.Append(" , ");
					}
					builder.Remove(builder.Length - 3, 3);
					builder.AppendLine();
				}
				return builder.ToString();
			}
		}

		private Point _outsideDistance = new Point(9999, 9999); //注意这个值代表无穷大的距离，不能太大，否则在平方计算时会越界，导致结果错误！
		private Point _insideDistance = new Point(0, 0);
		private Grid _insideGrid;
		private Grid _outsideGrid;
		private TexturePointValue _resultTextureValue = new TexturePointValue();
		public SDF8ssedt()
		{
			_insideGrid = new Grid();
			_outsideGrid = new Grid();
		}

		public void Generate(Texture2D srcTexture, Texture2D targetTexture, EColorChannel srcChanel = EColorChannel.A, EColorChannel targetChannel = EColorChannel.A)
		{
			int textureWidth = srcTexture.width;
			int textureHeight = srcTexture.height;

			_insideGrid.Resize(textureWidth, textureHeight);
			_outsideGrid.Resize(textureWidth, textureHeight);

			for (int y = 0; y < textureHeight; y++)
			{
				for (int x = 0; x < textureWidth; x++)
				{
					Color srcColor = srcTexture.GetPixel(x, y);
					float value =  SDFUtils.GetColorValue(ref srcColor, srcChanel);
					//根据阈值作为边界
					if (value < 0.5f)
					{
						Put(_insideGrid, x, y, _insideDistance);
						Put(_outsideGrid, x, y, _outsideDistance);
					}
					else
					{
						Put(_outsideGrid, x, y, _insideDistance);
						Put(_insideGrid, x, y, _outsideDistance);
					}
				}
			}

			//返回的insideMax和outsideMax我并不打算使用,每个内容的最大值距离不一致，可能导致映射到图片时标准不统一
			var insideMax = GenerateSDF(_insideGrid);
			var outsideMax = GenerateSDF(_outsideGrid);
			CalculateDistance(srcTexture, _resultTextureValue, insideMax, outsideMax);
			SDFUtils.WriteTexture(_resultTextureValue,targetTexture, targetChannel);
		}


		private Point Get(Grid g, int x, int y)
		{
			if (x >= 0 && y >= 0 && x < g.width && y < g.height)
				return g.grid[y, x];
			else
				return _outsideDistance;
		}

		private void Put(Grid g, int x, int y, Point p)
		{
			g.grid[y, x] = p;
		}

		private void Compare(Grid g, ref Point p, int x, int y, int offsetX, int offsetY)
		{
			Point other = Get(g, x + offsetX, y + offsetY);
			other.dx += offsetX;
			other.dy += offsetY;

			if (other.DistSq() < p.DistSq())
				p = other;
		}

		//和周围8个比较取最小值
		private double GenerateSDF(Grid g)
		{
			double maxValue = -1.0;

			// Pass 0
			for (int y = 0; y < g.height; y++)
			{
				for (int x = 0; x < g.width; x++)
				{
					Point p = Get(g, x, y);
					Compare(g, ref p, x, y, -1, 0);
					Compare(g, ref p, x, y, 0, -1);
					Compare(g, ref p, x, y, -1, -1);
					Compare(g, ref p, x, y, 1, -1);
					Put(g, x, y, p);
				}

				for (int x = g.width - 1; x >= 0; x--)
				{
					Point p = Get(g, x, y);
					Compare(g, ref p, x, y, 1, 0); //右
					Put(g, x, y, p);
				}
			}

			// Pass 1
			for (int y = g.height - 1; y >= 0; y--)
			{
				for (int x = g.width - 1; x >= 0; x--)
				{
					Point p = Get(g, x, y);
					Compare(g, ref p, x, y, 1, 0);
					Compare(g, ref p, x, y, 0, 1);
					Compare(g, ref p, x, y, -1, 1);
					Compare(g, ref p, x, y, 1, 1);
					Put(g, x, y, p);
				}

				for (int x = 0; x < g.width; x++)
				{
					Point p = Get(g, x, y);
					Compare(g, ref p, x, y, -1, 0);
					Put(g, x, y, p);

					//这个最大值用来后面将结果缩放到[0,1]
					if (maxValue < p.DistSq())
					{
						maxValue = p.DistSq();
					}
					//---
				}
			}
			return math.sqrt(maxValue);
		}

		/// <summary>
		/// 0.5为分界线
		/// </summary>
		private void CalculateDistance(Texture2D srcTexture, TexturePointValue result,double insideMax, double outsideMax)
		{
			int srcWidth = srcTexture.width;
			int srcHeight = srcTexture.height;
			result.Resize(srcWidth, srcHeight);

			for (int y = 0; y < srcHeight; y++)
			{
				for (int x = 0; x < srcWidth; x++)
				{
					// 计算距离
					double dist1 = math.sqrt(Get(_insideGrid, x, y).DistSq());
					double dist2 = math.sqrt(Get(_outsideGrid, x, y).DistSq());
					double dist = dist1 - dist2;

					//这里映射的方式，可以根据实际修改---
					double c = 0.5f; //0.5为分界线
					if (dist < 0)//内部，[0,0.5)
					{
						c += dist / outsideMax * 0.5f;
					}
					else//外部，(0.5,1]
					{
						c += dist / insideMax * 0.5f;
					}
					//----------------------------------
					float final = Mathf.Clamp01((float)c);
					result.grid[x,y] = final;
				}
			}
		}
	}
}
