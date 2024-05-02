Texture2D shaderTexture;
SamplerState samplerState;


// Terminal settings such as the resolution of the texture
cbuffer PixelShaderSettings: register(b0)
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

#define time Time

float2x2 mm2(float a){
    float c = cos(a), s = sin(a);
    return (float2x2(c,s,-s,c));
    }
float2x2 m2 = float2x2(0.95534, 0.29552, -0.29552, 0.95534);

float tri(float x){
    return (clamp(abs(frac(x)-0.5),0.01,0.49));
    }

float2 tri2(float2 p){
    return (float2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x))));
    }

float triNoise2d(float2 p, float spd)
{
    float z=1.8;
    float z2=2.5;
	float rz = 0.0;
    p = mul(p,mm2(p.x*0.06));
    float2 bp = float2(p);
	for (float i=0.0; i<5.0; i++ )
	{
        float2 dg = tri2(bp*1.85)*0.75;
        dg =mul(dg,mm2(time*spd));
        p -= dg/z2;

        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;
		p *= 1.21 + (rz-1.0)*0.02;
        
        rz += tri(p.x+tri(p.y))*z;
        p=mul(p,-m2);
	}
    return clamp(1./pow(rz*29., 1.3),0.,.55);
}

// //ooga booga why hash
 float hash21(float2 n){ return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453); }


float4 aurora(float3 ro, float3 rd, float4 gl_FragCoord)
{
    float4 col = float4(0.0,0.0,0.0,0.0);
    float4 avgCol = float4(0.0,0.0,0.0,0.0);
    
    for(int i=0;i<50;i++)
    {
        float of = 0.006*hash21(gl_FragCoord.xy)*smoothstep(0.,15., i);
        float pt = ((.8+pow(i,1.4)*.002)-ro.y)/(rd.y*2.+0.4);
        pt -= of;
    	float3 bpos = ro + pt*rd;
        float2 p = bpos.zx;
        float rzt = triNoise2d(p, 0.06);
        float4 col2 = float4(0,0,0, rzt);
        col2.rgb = (sin(1.-float3(2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;
        avgCol =  lerp(avgCol, col2, .5);
        col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);
        
    }
    
    col *= (clamp(rd.y*15.+.4,0.,1.));
    
    
    //return clamp(pow(col,float4(1.3))*1.5,0.,1.);
    //return clamp(pow(col,float4(1.7))*2.,0.,1.);
    //return clamp(pow(col,float4(1.5))*2.5,0.,1.);
    //return clamp(pow(col,float4(1.8))*1.5,0.,1.);
    
    //return smoothstep(0.,1.1,pow(col,float4(1.))*1.5);
    return col*1.8;
    //return pow(col,float4(1.))*2.
}

float3 nmzHash33(float3 q)
{
    int3 temp1= int3(q.x,q.y,q.z);
    uint3 p = uint3(temp1.x,temp1.y,temp1.z);
    p = p*uint3(374761393U, 1103515245U, 668265263U) + p.zxy + p.yzx;
    p = p.yzx*(p.zxy^(p >> 3U));
    
    float temp2=1.0/0xffffffffU;
     float3 temp3=float3(temp2,temp2,temp2);
     float temp4=p^(p >> 16U);
    	float3 temp5=float3(temp4,temp4,temp4);
    	
    return temp5*temp2;
}

float3 stars(float3 p)
{
    float3 c = float3(0.0,0.0,0.0);
    float res = Resolution.x*1.;
    
	for (int i=0;i<4;i++)
    {
        float3 q = frac(p*(.15*res))-0.5;
        float3 id = floor(p*(.15*res));
        float2 rn = nmzHash33(id).xy;
        //AAAAAAAAAAAAAAAA WHYYYYYYYYY
        float c2 = 1.-smoothstep(0.,.6,length(q));
        c2 *= step(rn.x,.0005+i*i*0.001);
        c += c2*(lerp(float3(1.0,0.49,0.1),float3(0.75,0.9,1.),rn.y)*0.1+0.9);
        p *= 1.3;
    }
    return c*c*.8;
}

float3 bg(float3 rd)
{
    float sd = dot(normalize(float3(-0.5, -0.6, 0.9)), rd)*0.5+0.5;
    sd = pow(sd, 5.);
    float3 col = lerp(float3(0.05,0.1,0.2), float3(0.1,0.05,0.2), sd);
    return col*.63;
}



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
  float4 sample = shaderTexture.Sample(samplerState, tex);
       sample += Blur(shaderTexture, tex, SCALED_GAUSSIAN_SIGMA) * 0.3f;
    sample = Scanline(sample, pos);

    const float4 iMouse=float4(255,255.0,0.0,0.0);
	float2 q = pos.xy / Resolution.xy;
    float2 p = q - 0.5;
    p.y=-p.y;
	p.x*=Resolution.x/Resolution.y;
    
    float3 ro = float3(0,0,-6.7);
    float3 rd = normalize(float3(p,1.3));
    float2 mo = iMouse.xy / Resolution.xy-.5;
    //mo = (mo==float2(-0.5,-0.5))?mo=float2(-0.1,0.1):mo;
	mo.x *= Resolution.x/Resolution.y;
    rd.yz = mul(rd.yz,mm2(mo.y));
    rd.xz = mul(rd.xz,mm2(mo.x + sin(time*0.05)*0.2));
    
    float3 col = float3(0.0,0.0,0.0);
    float3 brd = rd;
    float fade = smoothstep(0.,0.01,abs(brd.y))*0.1+0.9;
    
    col = bg(rd)*fade;
    
    if (rd.y > 0.){
        float4 aur = smoothstep(0.,1.5,aurora(ro,rd,pos))*fade;
        col += stars(rd);
        col = col*(1.-aur.a) + aur.rgb;
    }
    else //Reflections
    {
        rd.y = abs(rd.y);
        col = bg(rd)*fade*0.6;
        float4 aur = smoothstep(0.0,2.5,aurora(ro,rd,pos));
        col += stars(rd)*0.1;
        col = col*(1.-aur.a) + aur.rgb;
        float3 pos = ro + ((0.5-ro.y)/rd.y)*rd;
        float nz2 = triNoise2d(pos.xz*float2(0.5,0.7), 0.0);
        col += lerp(float3(0.2,0.25,0.5)*0.08,float3(0.3,0.3,0.5)*0.7, nz2*0.4);
    }
    


return sample+float4(col.r,col.g,col.b,1);
}