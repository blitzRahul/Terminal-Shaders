Texture2D shaderTexture;
SamplerState samplerState;

// Terminal settings such as the resolution of the texture
cbuffer PixelShaderSettings
{
    // The number of seconds since the pixel shader was enabled
    float Time;
    // UI Scale
    float Scale;
    // Resolution of the shaderTexture
    float2 Resolution;
    // Background color as rgba
    float4 Background;
};

// pi and tau (2 * pi) are useful constants when using trigonometric functions
#define LAYERS 50
	#define DEPTH .5
	#define WIDTH .3
	#define SPEED .6
    #define X_DIRECTION 1.0 // Control snowfall in the x-direction
    #define Y_DIRECTION 1.0 // Control snowfall in the y-direction
    #define Z_DIRECTION 0.0// Control snowfall in the z-direction (0 for no movement)

#define SCANLINE_FACTOR 0.5f
#define SCALED_SCANLINE_PERIOD Scale
#define SCALED_GAUSSIAN_SIGMA (2.0f * Scale)

static const float M_PI = 3.14159265f;





float Gaussian2D(float x, float y, float sigma)
{
    return 1 / (sigma * sqrt(2 * M_PI)) * exp(-0.5 * (x * x + y * y) / sigma / sigma);
}

float4 Blur(Texture2D input, float2 tex_coord, float sigma)
{
    float width, height;
    shaderTexture.GetDimensions(width, height);

    float texelWidth = 1.0f / width;
    float texelHeight = 1.0f / height;

    float4 color = { 0, 0, 0, 0 };

    float sampleCount = 13;

    for (float x = 0; x < sampleCount; x++)
    {
        float2 samplePos = { 0, 0 };
        samplePos.x = tex_coord.x + (x - sampleCount / 2.0f) * texelWidth;

        for (float y = 0; y < sampleCount; y++)
        {
            samplePos.y = tex_coord.y + (y - sampleCount / 2.0f) * texelHeight;
            color += input.Sample(samplerState, samplePos) * Gaussian2D(x - sampleCount / 2.0f, y - sampleCount / 2.0f, sigma);
        }
    }

    return color;
}

float SquareWave(float y)
{
    return 1.0f - (floor(y / SCALED_SCANLINE_PERIOD) % 2.0f) * SCANLINE_FACTOR;
}

float4 Scanline(float4 color, float4 pos)
{
    float wave = SquareWave(pos.y);

    // TODO:GH#3929 make this configurable.
    // Remove the && false to draw scanlines everywhere.
    if (length(color.rgb) < 0.2f && false)
    {
        return color + wave * 0.1f;
    }
    else
    {
        return color * wave;
    }
}






float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
//hello :)
	// Read the color value at the current texture coordinate (tex)
    float4 sample = shaderTexture.Sample(samplerState, tex);
       sample += Blur(shaderTexture, tex, SCALED_GAUSSIAN_SIGMA) * 0.3f;
    sample = Scanline(sample, pos);

     const float3x3 p = {13.323122,23.5112,21.71123,21.1212,28.7312,11.9312,21.8112,14.7212,61.3934};
    float2 uv=-1.0*float2(1.,Resolution.y/Resolution.x)*pos.xy/Resolution.xy;
    float3 acc=float3(.0,0.0,0.0);
    float dof=5.0*sin(Time*0.1);
    for(int i=0;i<LAYERS;i++){
         float fi=float(i);
         float2 q=uv*(1.0+fi*DEPTH)+float2(X_DIRECTION,Y_DIRECTION)*SPEED*Time/(1.0+fi*DEPTH*0.03);
         q+=float2(q.y*(WIDTH*fmod(fi*7.238917,1.0)-WIDTH*0.5),SPEED*Time/(1.0+fi*DEPTH*0.03));
         float3 n=float3(floor(q),31.189+fi);
         float3 m=floor(n)*0.00001+frac(n);
         float3 mp=(31415.9+m)/frac(mul(p,m));
         float3 r=frac(mp);
         float2 s= abs(fmod(q,1.0)-0.5+0.9*r.xy-0.45);
         s+=0.01*abs(2.0*frac(10.0*q.yx)-1.0);
         float d=0.6*max(s.x-s.y,s.x+s.y)+max(s.x,s.y)-0.01;
         float edge=0.005 + 0.05*min(0.5*abs(fi-0.5-dof),1.0);
         float temp=smoothstep(edge,-edge,d)*(r.x/(1.0+0.02*i*DEPTH));
         acc+=float3(temp,temp,temp);
     }
    //float2 uv=float2(1.0,Resolution.y/Resolution.x)*fragCoord.xy

    // Draw the terminal graphics over the background
    return (sample+float4(acc.r,acc.g,acc.b,0.5));
}