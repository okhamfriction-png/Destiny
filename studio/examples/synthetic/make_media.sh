#!/usr/bin/env bash
# Génère des rushes factices (aucune donnée réelle) pour tester la chaîne complète :
#  - caméra 16:9 1920×1080 25 i/s de 120 s, nommée comme une DJI, avec son proxy LRF ;
#  - deux micros-cravates 48 kHz : m1 « parle » (voix voisée, silencieux de 64 à 76 s),
#    m2 parle de 23 à 43 s puis chuchote en coulisses (bruit faible non voisé) de 63 à 78 s.
# Les micros démarrent 3 s avant la caméra (horodatages des noms de fichiers).
set -euo pipefail
OUT="${1:-$(dirname "$0")/media}"
mkdir -p "$OUT"
cd "$OUT"
# Voix « parlée » : sinus modulé en syllabes, répliques irrégulières (chirps) pour
# que le signal ne soit pas périodique (sinon la corrélation a plusieurs pics).
voice='0.25*(sin(2*PI*140*t)+0.5*sin(2*PI*280*t))*(0.5+0.5*sin(2*PI*(3+t/40)*t))*gt(sin(2*PI*0.23*t)+sin(2*PI*0.071*t*t/10),0)*not(between(t,64,76))'
ffmpeg -v error -y -f lavfi -i "aevalsrc='${voice}':s=48000:d=123" -ac 1 -c:a pcm_s24le TX00_MIC001_20261008_201103_orig.wav
# m2 : parle de 23 à 43 s puis chuchote de 63 à 78 s (temps micro).
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.3*sin(2*PI*210*t)*(0.5+0.5*sin(2*PI*(5+t/30)*t))*gt(sin(2*PI*0.37*t*t/20),0.2)*between(t,23,43)':s=48000:d=123" \
  -f lavfi -i "anoisesrc=c=pink:a=0.15:s=48000:d=123" \
  -filter_complex "[1]highpass=f=1500,volume='between(t,63,78)':eval=frame[w];[0][w]amix=inputs=2:normalize=0" \
  -ac 1 -c:a pcm_s24le TX01_MIC002_20261008_201103_orig.wav
# Caméra : mire + horloge, audio = mix des micros (décalé de 3,37 s : le calage par corrélation doit corriger les 0,37 s que les noms de fichiers ignorent) atténué + bruit de salle.
ffmpeg -v error -y -f lavfi -i "testsrc2=s=1920x1080:r=25:d=120" \
  -i TX00_MIC001_20261008_201103_orig.wav -i TX01_MIC002_20261008_201103_orig.wav \
  -f lavfi -i "anoisesrc=c=brown:a=0.01:s=48000:d=120" \
  -filter_complex "[1]atrim=start=3.37,asetpts=PTS-STARTPTS[a1];[2]atrim=start=3.37,asetpts=PTS-STARTPTS[a2];[a1][a2][3]amix=inputs=3:normalize=0,volume=0.5[a]" \
  -map 0:v -map "[a]" -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p -c:a aac -t 120 DJI_20261008201106_0001_D_P004.MP4
# Proxy LRF 1280×720 synchrone.
ffmpeg -v error -y -i DJI_20261008201106_0001_D_P004.MP4 -vf scale=1280:720 -c:v libx264 -preset ultrafast -crf 30 -c:a aac -f mp4 DJI_20261008201106_0001_D_P004.LRF
ls -la
