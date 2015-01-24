//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/

#include <metal_stdlib>
using namespace metal;

struct Particle
{
    float positionX;
    float positionY;
    float velocityX;
    float velocityY;
};

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device Particle *inParticles [[ buffer(0) ]],
                                   device Particle *outParticles [[ buffer(1) ]],
                                   
                                   constant Particle &inGravityWell [[ buffer(2) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const uint2 particlePosition(inParticles[id].positionX, inParticles[id].positionY);
    
    const Particle inParticle = inParticles[id];
    
    const int type = id % 3;
    
    const float3 thisColor = inTexture.read(particlePosition).rgb;
    const float4 outColor(thisColor.r + (type == 0 ? 0.25 : 0.0),
                          thisColor.g + (type == 1 ? 0.25 : 0.0),
                          thisColor.b + (type == 2 ? 0.25 : 0.0),
                          1.0);

    const float dist = fast::distance(float2(inParticle.positionX, inParticle.positionY), float2(inGravityWell.positionX, inGravityWell.positionY));
    
    const float factor = (1 / dist) * (type == 0 ? 0.1 : (type == 1 ? 0.125 : 0.15));
    
    const Particle outParticle = {
        .velocityX =  (inParticle.velocityX * 0.999) + (inGravityWell.positionX - inParticle.positionX) * factor,
        .velocityY =  (inParticle.velocityY * 0.999) + (inGravityWell.positionY - inParticle.positionY) * factor,
        .positionX =  inParticle.positionX + inParticle.velocityX,
        .positionY =  inParticle.positionY + inParticle.velocityY
        };

    outParticles[id] = outParticle;
    
    uint2 textureCoordinate(fast::floor(id / 1024.0f),id % 1024);
    
    if (textureCoordinate.x < 1024 && textureCoordinate.y < 1024)
    {
        float4 accumColor = inTexture.read(textureCoordinate);
        
        for (int j = -1; j <= 1; j++)
        {
            for (int i = -1; i <= 1; i++)
            {
                uint2 kernelIndex(textureCoordinate.x + i, textureCoordinate.y + j);
                accumColor.rgb += inTexture.read(kernelIndex).rgb;
            }
        }
        
        accumColor.rgb = (accumColor.rgb / 10.5f);
        accumColor.a = 1.0f;
        
        outTexture.write(accumColor, textureCoordinate);
    }
    


    outTexture.write(outColor, particlePosition);
}