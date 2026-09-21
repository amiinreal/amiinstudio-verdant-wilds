"""Original 80-second seamless, quiet harp-and-pad score; no external samples."""
from pathlib import Path
import numpy as np
import wave
rate=22050
duration=80
audio=np.zeros((rate*duration,2),np.float64)
rng=np.random.default_rng(73)
def note(start,midi,length,gain,pan,pad=False):
    t=np.arange(int(rate*length))/rate
    f=440*2**((midi-69)/12)
    if pad:
        env=np.sin(np.pi*t/length)**2
        sound=(np.sin(2*np.pi*f*t)+.17*np.sin(2*np.pi*f*2.001*t))*.45
    else:
        env=(1-np.exp(-t*45))*np.exp(-t/1.5)*np.minimum(1,(length-t)/.4)
        sound=np.sin(2*np.pi*f*t)+.23*np.sin(2*np.pi*2*f*t)*np.exp(-t*2)+.06*np.sin(2*np.pi*3*f*t)
    sound*=env*gain
    idx=(int(start*rate)+np.arange(len(t)))%len(audio)
    audio[idx,0]+=sound*np.sqrt(1-pan); audio[idx,1]+=sound*np.sqrt(pan)
for bar,chord in enumerate([[48,55,60,64],[45,52,57,60],[41,48,53,60],[43,50,55,62]]*2):
    for pitch in chord: note(bar*10,pitch,13,.033,.5,True)
    for beat in [0,2,3.5,6,8]:
        pitch=chord[int(rng.integers(1,4))]+12
        note(bar*10+beat,pitch,5,.09,float(rng.uniform(.25,.75)))
# Circular, low-level echoes preserve a gapless loop.
audio+=np.roll(audio,int(rate*.43),axis=0)*.16+np.roll(audio,int(rate*.79),axis=0)*.09
path=Path(__file__).resolve().parents[2]/'Adventure/generated/PeacefulWoodland.wav'
with wave.open(str(path),'wb') as out:
    out.setnchannels(2); out.setsampwidth(2); out.setframerate(rate)
    out.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
print(path, 'peak',np.max(np.abs(audio)))
