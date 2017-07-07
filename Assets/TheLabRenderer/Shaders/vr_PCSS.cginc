	static float2 poissonDisk20[20] =
	{ 
		float2 ( 0.2111217f, -0.702272f),
		float2 ( 0.4705284f, -0.3929689f),
		float2 ( 0.5897741f, -0.7773586f),
		float2 ( -0.154882f, -0.4878186f),
		float2 ( -0.08802283f, -0.9208807f),
		float2 ( 0.8209927f, -0.1620779f),
		float2 ( 0.4817981f, 0.04513926f),
		float2 ( 0.0881269f, -0.04166441f),
		float2 ( -0.3571257f, -0.1645149f),
		float2 ( -0.651518f, -0.7295282f),
		float2 ( -0.2112222f, 0.1975897f),
		float2 ( -0.735217f, -0.2109533f),
		float2 ( -0.84478f, 0.1897396f),
		float2 ( -0.5461306f, 0.6595152f),
		float2 ( -0.08115801f, 0.5445821f),
		float2 ( -0.2131593f, 0.8739875f),
		float2 ( 0.4049454f, 0.4862685f),
		float2 ( 0.8282107f, 0.5104074f),
		float2 ( 0.2774227f, 0.84667f),
		float2 ( 0.9371698f, 0.1748641f)
	};
	
	static float2 poissonDisk25[25] =
	{
		float2 ( -0.6351818f, 0.2172711f),
		float2 ( -0.1499606f, 0.2320675f),
		float2 ( -0.67978f, 0.6884924f),
		float2 ( -0.7758647f, -0.253409f),
		float2 ( -0.4731916f, -0.2832723f),
		float2 ( -0.3330079f, 0.6430059f),
		float2 ( -0.1384151f, -0.09830225f),
		float2 ( -0.8182327f, -0.5645939f),
		float2 ( -0.9198472f, 0.06549802f),
		float2 ( -0.1422085f, -0.4872109f),
		float2 ( -0.4980833f, -0.5885599f),
		float2 ( -0.3326159f, -0.8496148f),
		float2 ( 0.3066736f, -0.1401997f),
		float2 ( 0.1148317f, 0.374455f),
		float2 ( -0.0388568f, 0.8071329f),
		float2 ( 0.4102885f, 0.6960295f),
		float2 ( 0.5563877f, 0.3375377f),
		float2 ( -0.01786576f, -0.8873765f),
		float2 ( 0.234991f, -0.4558438f),
		float2 ( 0.6206775f, -0.1551005f),
		float2 ( 0.6640642f, -0.5691427f),
		float2 ( 0.7312726f, 0.5830168f),
		float2 ( 0.8879707f, 0.05715213f),
		float2 ( 0.3128296f, -0.830803f),
		float2 ( 0.8689764f, -0.3397973f)
	};

	uniform sampler2D unity_RandomRotation16;

	
	static fixed3 sampleOffsetDirections[20] =
	{
	   fixed3( 1,  1,  1), fixed3( 1, -1,  1), fixed3(-1, -1,  1), fixed3(-1,  1,  1), 
	   fixed3( 1,  1, -1), fixed3( 1, -1, -1), fixed3(-1, -1, -1), fixed3(-1,  1, -1),
	   fixed3( 1,  1,  0), fixed3( 1, -1,  0), fixed3(-1, -1,  0), fixed3(-1,  1,  0),
	   fixed3( 1,  0,  1), fixed3(-1,  0,  1), fixed3( 1,  0, -1), fixed3(-1,  0, -1),
	   fixed3( 0,  1,  1), fixed3( 0, -1,  1), fixed3( 0, -1, -1), fixed3( 0,  1, -1)
	};
	
	//float2 offsetDirections25[25];
	//float3 offsetDirections20[20];
	float3 offsetDirections25[25];
//};

// Returns a random number based on a float3 and an index.
float randInd(float3 seed, int i)
{
	float4 seed4 = float4(seed,i);
	float dt = dot(seed4, float4(12.9898,78.233,45.164,94.673));
	return frac(sin(dt) * 43758.5453);
}

float rand01(float3 seed)
{
   float dt = dot(seed, float3(12.9898,78.233,45.5432));// project seed on random constant vector   
   return frac(sin(dt) * 43758.5453);// return only fractional part
}

float3 randDir(float3 seed)
{
	float3 dt = float3 (dot(seed, float3 (12.9898,78.233,45.5432)), dot(seed, float3 (78.233,45.5432,12.9898)), dot(seed, float3 (45.5432,12.9898,78.233)));
	return sin(frac(sin(dt) * 43758.5453)*6.283285);
}

int randInt(float3 seed, int maxInt)
{
   return int((float(maxInt) * rand01(seed), maxInt)%16);//fmod() function equivalent as % operator
}

// returns random angle
float randAngle(float3 seed)
{
	return rand01(seed)*6.283285;//*(1.0 - _LightShadowData.r)*10//can be tweaked globally to range between Banding and Noisy
}


