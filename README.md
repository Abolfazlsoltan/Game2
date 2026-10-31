# Small Warriors

نبرد ارتش آدمک‌ها برای اندروید. نسخهٔ ۱.۰ میدان روز، سه تپهٔ طلا، صف ارتش، کنترل مستقیم با دکمهٔ حمله و مهارت، ضربه از پشت، و سه جادوی فراخوان، درمان و لرزه را دارد. الهام از بازی‌های استراتژی خطی مثل Stick War Legacy، با نام، ظاهر و ارتش مخصوص همین بازی.

A landscape stick-legion strategy game for Android, built with Godot 4.5. نسخه ۰.۹ میدان را نزدیک‌تر نشان می‌دهد: دوربین دنبال سرباز انتخاب‌شده می‌رود، کشیدن میدان اطراف را نشان می‌دهد، و دکمه‌های آموزش مثل بازی‌های اندرویدی بالای صفحه است.

## Play
- Miners haul gold from the center vein back to your statue. A miner you control digs faster.
- Train Miner, Sword, Archer, Spear, Mage, and Giant. New troops unlock as the campaign advances.
- **حمله** sends the line at their statue. Spears and swords take the front. Archers and mages hold a firing line behind them. **دفاع** holds your road. **عقب‌نشینی** pulls everyone, miners included, back behind the wall.
- Tap a soldier to take direct control. They stop following the army order, a star marks them, and their hits land twice as hard. The stick moves them. The round button is their skill.
- Destroy the enemy statue. If yours falls, the battle is lost.
- Twelve campaign battles with progressive unit unlocks and star records.
- Three campaign difficulty levels; higher difficulty increases enemy statue health, damage, and starting gold. Your choice is saved.
- Endless Survival: enemy waves grow stronger; best wave is saved locally.
- Five-round Tournament with escalating enemy rosters and a saved win record.

## Download the APK
Each push to `main` runs **Build Android APK**.

1. Open the **Actions** tab.
2. Open the latest successful run.
3. Download the artifact `SmallWarriors-Android-APK`.
4. Unzip it and install `SmallWarriors.apk` on an Android phone.

The APK is a debug build for testing. Landscape only. Campaign progress, survival records, tournament wins, and sound preferences are stored at `user://small_warriors.cfg`.

## Desktop keys
`WASD` move the selected soldier. `J` or `Space` uses their skill. `1-6` train. `F` attack, `G` defend, `H` garrison. `Esc` pauses.

## Local run
Godot 4.5. Open `project.godot` and press F5.


### Character rendering

Version 0.9 uses an original silhouette-first art pass inspired by the readability of classic side-view stick-army strategy games. Soldiers have dark, articulated limbs and rounded heads; miners carry a lamp, pickaxe and gold sack; swordsmen use a crested helmet and metal chest plate; archers carry a hood, quiver and bow; spear units have a shield; mages wear a pointed hood and cloak with a glowing focus; giants have a broad stone-like silhouette and heavy club. Friendly and enemy gear use separate muted accents. Walking, running, jumping, mining, spell gestures, hit reactions, selection and health bars remain part of the existing animated 2.5D renderer. This is original procedural art, not copied sprites or full 3D Skeleton3D models.
