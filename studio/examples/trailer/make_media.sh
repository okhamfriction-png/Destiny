#!/usr/bin/env bash
# Médias synthétiques (aucune donnée réelle) pour le trailer d'exemple du moteur B :
#  - cam : « caméra plan large » 1920×1080 25 i/s de 60 s (testsrc2) + son de salle, avec
#    son proxy LRF 1280×720 synchrone ;
#  - stage : second plan 1920×1080 (dégradés chauds animés) ;
#  - music.m4a : musique de 30 s — pulsation (noire = 0,5 s) avec trois accents à
#    4,9 / 5,6 / 6,4 s, creux 14,6–16,4 s, gros coup de bascule à 16,4 s, chaos,
#    quasi-silence 19,8–20,3 s puis le coup le plus fort à 20,3 s ;
#  - rev1..3.png : fausses captures d'avis (texte générique).
#
# Calage : la carte finale est à 18,3 s dans la vidéo ; music::align_hit(20,3, 18,3)
# donne (at 0, offset 2,0), valeurs reprises dans project.json.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/media}"
FONT="$HERE/../../assets/fonts/Montserrat-SemiBold.ttf"
# drawtext exige un ffmpeg avec freetype : sur Mac, le `ffmpeg` de Homebrew n'en a pas,
# on prend `ffmpeg-full` (keg-only) s'il est installé, comme destiny-cli.
FF="${DESTINY_FFMPEG:-}"
if [ -z "$FF" ]; then
  for c in /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg /usr/local/opt/ffmpeg-full/bin/ffmpeg ffmpeg; do
    command -v "$c" >/dev/null && { FF="$c"; break; }
  done
fi
ffmpeg() { "$FF" "$@"; }
mkdir -p "$OUT"
cd "$OUT"

# --- caméra + proxy ----------------------------------------------------------------
room='0.05*sin(2*PI*180*t)*(0.5+0.5*sin(2*PI*3.1*t))*gt(sin(2*PI*0.21*t),0)+0.25*between(t,40,41.6)*sin(2*PI*(300+200*sin(2*PI*7*t))*t)'
ffmpeg -v error -y -f lavfi -i "testsrc2=s=1920x1080:r=25:d=60" \
  -f lavfi -i "aevalsrc='${room}':s=48000:d=60" \
  -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p -c:a aac -shortest DJI_20261008201106_0001_D_P004.MP4
ffmpeg -v error -y -i DJI_20261008201106_0001_D_P004.MP4 -vf scale=1280:720 \
  -c:v libx264 -preset veryfast -crf 26 -c:a aac -f mp4 DJI_20261008201106_0001_D_P004.LRF

# --- second plan ---------------------------------------------------------------------
ffmpeg -v error -y -f lavfi -i "gradients=s=1920x1080:r=25:d=40:c0=0x2a1405:c1=0xe6b446:c2=0x0b0907:c3=0x7a3b12:speed=0.02:seed=7" \
  -vf "drawgrid=w=160:h=160:t=2:c=0x0b0907@0.35" -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p stage.mp4

# --- musique -------------------------------------------------------------------------
kick='sin(2*PI*55*mod(t,0.5))*exp(-mod(t,0.5)*14)'
kick4='sin(2*PI*60*mod(t,0.25))*exp(-mod(t,0.25)*16)'
stab() { echo "0.55*gte(t,$1)*sin(2*PI*330*(t-$1))*exp(-(t-$1)*9)"; }
pulse="(0.30*${kick}+0.05*sin(2*PI*110*t)*(0.6+0.4*sin(2*PI*0.5*t))+$(stab 4.9)+$(stab 5.6)+$(stab 6.4))*lt(t,14.6)"
dip="0.03*sin(2*PI*110*t)*between(t,14.6,16.4)"
bascule="(0.85*sin(2*PI*45*(t-16.4))*exp(-(t-16.4)*2.5)+0.38*${kick4}+0.06*sin(2*PI*220*t))*between(t,16.4,19.8)"
calm="0.003*sin(2*PI*110*t)*between(t,19.8,20.3)"
final="gte(t,20.3)*(0.9*sin(2*PI*40*(t-20.3))*exp(-(t-20.3)*1.1)+0.45*sin(2*PI*80*(t-20.3))*exp(-(t-20.3)*1.8)+0.25*sin(2*PI*120.5*(t-20.3))*exp(-(t-20.3)*1.4)+0.08*sin(2*PI*220*t))"
ffmpeg -v error -y -f lavfi -i "aevalsrc='${pulse}+${dip}+${bascule}+${calm}+${final}':s=48000:d=30" \
  -c:a aac -b:a 192k music.m4a

# --- fausses captures d'avis ---------------------------------------------------------
review() {
  ffmpeg -v error -y -f lavfi -i "color=c=white:s=1000x560:d=1" -frames:v 1 -vf "\
drawbox=x=0:y=0:w=iw:h=96:c=0x2b2b2b:t=fill,\
drawtext=fontfile=$FONT:text='AVIS DU PUBLIC':x=40:y=32:fontsize=30:fontcolor=white,\
drawtext=fontfile=$FONT:text='$2':x=40:y=140:fontsize=34:fontcolor=0x222222,\
drawtext=fontfile=$FONT:text='Note 10/10':x=40:y=200:fontsize=30:fontcolor=0xd18b00,\
drawtext=fontfile=$FONT:text='$3':x=40:y=280:fontsize=30:fontcolor=0x333333,\
drawtext=fontfile=$FONT:text='$4':x=40:y=330:fontsize=30:fontcolor=0x333333,\
drawtext=fontfile=$FONT:text='Spectateur vérifié':x=40:y=470:fontsize=24:fontcolor=0x888888" "$1"
}
review rev1.png "Camille" "Un spectacle unique, rien n est écrit" "et pourtant tout tombe juste. Bravo !"
review rev2.png "Julien" "On a ri du début à la fin." "Les comédiens sont incroyables."
review rev3.png "Sarah" "Je reviens la semaine prochaine" "avec toute ma famille !"

ls -la "$OUT"
