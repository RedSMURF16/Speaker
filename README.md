<h1 align="center">Speaker</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=KGT44y-rT7M"><img src="https://img.youtube.com/vi/KGT44y-rT7M/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin adds placeable music speakers to Counter-Strike 1.6, allowing players to play music through customizable speakers.
Players can interact with speakers to change songs, adjust volume and control playback. Speakers can play songs sequentially or randomly, with optional screen-shaking effects for nearby players.
- Place and configure speakers around the map
- Play customizable playlists with sequential or random playback
- Change songs, adjust volume and control speaker power
- Configure access flags, sound attenuation and screen-shaking effects
- Save and load speaker placements per map
- Use short, loopable WAV clips compatible with GoldSrc rather than full songs
- Use supported PCM WAV files with clean loop points and no noticeable silence or abrupt transitions

## ⚙️ Configuration
```ini
# To add a new Speaker, follow the example below:
# [Speaker Name]
# SPEAKER_FLAGS       = a - Shake
# SPEAKER_MODE        = 0 - Sequential   1 - Random
# SPEAKER_USE_FLAGS   = 0 - Everyone, 1 - Immunity, 2 - Reservation, 4 - Kick, 8 - Ban, 16 - Slay, 32 - Change Map, 64 - Change CVARs, 128 - Execute Config, 256 - Chat, 512 - Start Votes, 1024 - Change Password, 2048 - Use Key, 4096 - Level A, 8192 - Level B, 16384 - Level C, 32768 - Level D, 65536 - Level E, 131072 - Level F, 262144 - Level G, 524288 - Level H, 1048576 - Menu, 2097152 - Temporary Ban, 16777216 - Admin, 33554432 - User
# SPEAKER_ATTENUATION = Sound attenuation (lower values carry farther)
# SPEAKER_SONG        = Speaker/Example.wav
```

## 🔄 Changelog
```text
* v1.0: Initial release.
```
