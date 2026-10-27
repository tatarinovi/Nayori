NAOMI HAORI — layered QML sprite
Source: standing haori painting, assets/naomi/haori/source.png
Rebuild: python3 scripts/naomi-haori-layers.py

All part PNGs are RGBA, 470x1024, and share one origin.
Render back to front:
legs, hair_back, body, clothing, coat, head, arm, hair_front, hand, ribbons, eyes, mouth
face_blink covers the eyes with the closed eyes from expressions-sheet.png. It stays hidden while the eyes are open.
face_sleepy is the sleepy eyes from that sheet. It shows from midnight to 06:00 local time.
face_talk is the open mouth from that sheet. It shows while a line is on screen, and the mouth opens and closes until the line goes away.
face_blush is a small blush taken from the laugh. It shows while the character is petted, under the hair and the hand.
Rebuild the two faces: python3 scripts/naomi-haori-expressions.py
eyes_happy, mouth_smile and blush appear while the character is petted.

The rest pose matches the source. Motion is a small idle: breath, head, hair, coat, ribbons, blink.
While petted, the eyes close, the head leans toward the cursor and nods, and the hair and ribbons follow a little later.
Legs do not move. The hand on the cheek turns with the head.
Hidden cloth under the haori was not in the painting and is not invented here.
