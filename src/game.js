const GAME_WIDTH = 640;
const GAME_HEIGHT = 360;
const HUD_TOP = 300;
const LANE_Y = [236, 264, 292];
const COLUMN_X = [180, 250, 320, 390, 460, 530];
const ENEMY_SPAWN_X = 612;
const SLAVYAN_X = 74;
const SLAVYAN_Y = 280;
const GRID_HOVER_COLOR = 0xf0d992;
const POST_WAVE_GAPS = [9200, 9800, 10400, 6200];
const INTRO_TEXT =
  "Свобода не достается просто так.\n\n" +
  "За свободу надо бороться. Одна из таких битв произошла 02.04.2026, когда во время " +
  "демократического заседания думы в здание суда ворвались карательные органы с целью " +
  "похитить Славяна Дмитрия Михайловича, законного представителя народа.\n\n" +
  "И только предмет мебели встал между ними.\n\n" +
  "У вас есть возможность увидеть, как произошла та битва.";

const SLAVYAN_SLOGANS = [
  "Демократия устоит!",
  "Нашу мебель не сломить!",
  "Маркелов, нам нужны боеприпасы!",
  "Законный представитель не сдается!",
  "Мебель держит линию свободы!",
  "Увеличьте финансирование Вайнштейна!",
];

class RetroSfx {
  constructor() {
    const AudioContextCtor = window.AudioContext || window.webkitAudioContext;
    this.context = AudioContextCtor ? new AudioContextCtor() : null;
    this.master = null;

    if (this.context) {
      this.master = this.context.createGain();
      this.master.gain.value = 0.12;
      this.master.connect(this.context.destination);
    }
  }

  async unlock() {
    if (!this.context) {
      return false;
    }

    if (this.context.state !== "running") {
      try {
        await this.context.resume();
      } catch (error) {
        return false;
      }
    }

    return this.context.state === "running";
  }

  isReady() {
    return Boolean(this.context) && this.context.state === "running";
  }

  tone({
    frequency = 440,
    duration = 0.08,
    volume = 0.2,
    type = "square",
    when = 0,
    slideTo = null,
  }) {
    if (!this.isReady()) {
      return;
    }

    const now = this.context.currentTime + when;
    const oscillator = this.context.createOscillator();
    const gain = this.context.createGain();

    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, now);
    if (slideTo) {
      oscillator.frequency.exponentialRampToValueAtTime(slideTo, now + duration);
    }

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(volume, now + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

    oscillator.connect(gain);
    gain.connect(this.master);
    oscillator.start(now);
    oscillator.stop(now + duration + 0.02);
  }

  typeBlip(index) {
    const frequency = index % 2 === 0 ? 740 : 620;
    this.tone({
      frequency,
      duration: 0.035,
      volume: 0.06,
      type: "square",
    });
  }

  buttonReveal() {
    this.tone({ frequency: 392, slideTo: 523, duration: 0.11, volume: 0.09, type: "triangle", when: 0 });
    this.tone({ frequency: 523, slideTo: 659, duration: 0.12, volume: 0.08, type: "triangle", when: 0.08 });
    this.tone({ frequency: 659, duration: 0.16, volume: 0.08, type: "triangle", when: 0.16 });
  }

  buttonClick() {
    this.tone({ frequency: 260, slideTo: 520, duration: 0.18, volume: 0.11, type: "square" });
    this.tone({ frequency: 180, duration: 0.12, volume: 0.04, type: "sine", when: 0.02 });
  }

  battleStart() {
    this.tone({ frequency: 220, slideTo: 330, duration: 0.14, volume: 0.08, type: "triangle", when: 0 });
    this.tone({ frequency: 330, slideTo: 494, duration: 0.16, volume: 0.08, type: "triangle", when: 0.1 });
    this.tone({ frequency: 494, duration: 0.22, volume: 0.07, type: "triangle", when: 0.2 });
  }
}

const SFX = new RetroSfx();

const UNIT_DEFS = {
  chair: {
    name: "Стул",
    kind: "defender",
    cost: 45,
    hp: 220,
    damage: 22,
    range: 42,
    cooldown: 900,
    speed: 0,
    attackType: "melee",
    sprite: "chair",
    sheet: "chair_sheet",
  },
  weinstein: {
    name: "Вайнштейн",
    kind: "defender",
    cost: 65,
    hp: 105,
    damage: 18,
    range: 170,
    cooldown: 850,
    speed: 0,
    projectileSpeed: 230,
    attackType: "projectile",
    sprite: "weinstein",
    sheet: "weinstein_sheet",
  },
  prosecutor: {
    name: "Прокурор",
    kind: "attacker",
    hp: 110,
    damage: 14,
    range: 28,
    cooldown: 950,
    speed: 20,
    attackType: "melee",
    sprite: "prosecutor",
    sheet: "prosecutor_sheet",
  },
  guard: {
    name: "ФСВНГ",
    kind: "attacker",
    hp: 165,
    damage: 22,
    range: 30,
    cooldown: 760,
    speed: 30,
    attackType: "melee",
    sprite: "guard",
    sheet: "guard_sheet",
  },
  slavyan: {
    name: "Славян",
    kind: "objective",
    hp: 260,
    sprite: "slavyan_sheet",
  },
};

class BootScene extends Phaser.Scene {
  constructor() {
    super("boot");
  }

  preload() {
    this.add.rectangle(320, 180, 640, 360, 0x11080a);
    const title = this.add.text(320, 130, "Загрузка арены", {
      fontFamily: "monospace",
      fontSize: "24px",
      color: "#f4ede2",
    }).setOrigin(0.5);
    const progressBox = this.add.rectangle(320, 192, 292, 18, 0x2b1619)
      .setStrokeStyle(2, 0xe3c26a, 0.8);
    const progressBar = this.add.rectangle(176, 192, 0, 10, 0xe3c26a)
      .setOrigin(0, 0.5);
    const status = this.add.text(320, 232, "Подготовка думы...", {
      fontFamily: "monospace",
      fontSize: "14px",
      color: "#d7c6b0",
    }).setOrigin(0.5);

    this.load.on("progress", (value) => {
      progressBar.width = 280 * value;
    });

    this.load.on("fileprogress", (file) => {
      status.setText(`Загрузка: ${file.key}`);
    });

    this.load.image("background", "assets/pixel_art/animated/background_hall_v2.png");
    this.load.json("manifest", "assets/pixel_art/animated/sprite_manifest.json");
    this.load.spritesheet("slavyan_sheet", "assets/pixel_art/animated/slavyan_sheet.png", {
      frameWidth: 64,
      frameHeight: 64,
    });
    this.load.spritesheet("weinstein_sheet", "assets/pixel_art/animated/weinstein_sheet.png", {
      frameWidth: 64,
      frameHeight: 64,
    });
    this.load.spritesheet("chair_sheet", "assets/pixel_art/animated/chair_sheet.png", {
      frameWidth: 64,
      frameHeight: 64,
    });
    this.load.spritesheet("prosecutor_sheet", "assets/pixel_art/animated/prosecutor_sheet.png", {
      frameWidth: 64,
      frameHeight: 64,
    });
    this.load.spritesheet("guard_sheet", "assets/pixel_art/animated/guard_sheet.png", {
      frameWidth: 64,
      frameHeight: 64,
    });

    this.load.once("complete", () => {
      title.setText("Арена готова");
    });
  }

  create() {
    this.createAnimations();
    this.scene.start("intro");
  }

  createAnimations() {
    const manifest = this.cache.json.get("manifest");
    const { units, animations } = manifest;

    Object.entries(units).forEach(([unitKey, unitData]) => {
      if (!unitData.file.endsWith(".png")) {
        return;
      }

      Object.entries(animations).forEach(([animKey, animDef]) => {
        const key = `${unitKey}-${animKey}`;
        if (this.anims.exists(key)) {
          return;
        }

        this.anims.create({
          key,
          frames: this.anims.generateFrameNumbers(unitData.file.replace(".png", ""), {
            frames: animDef.frames,
          }),
          frameRate: animDef.frameRate,
          repeat: animDef.repeat,
        });
      });
    });
  }
}

class IntroScene extends Phaser.Scene {
  constructor() {
    super("intro");
    this.fullText = INTRO_TEXT;
    this.currentIndex = 0;
    this.finishedTyping = false;
  }

  create() {
    this.add.rectangle(320, 180, 640, 360, 0x090608);
    this.add.rectangle(320, 180, 616, 332, 0x140b0d, 0.94)
      .setStrokeStyle(3, 0xe3c26a, 0.75);
    this.add.rectangle(320, 180, 588, 304, 0x0f0809, 0.92)
      .setStrokeStyle(1, 0xf0d992, 0.28);

    this.add.text(320, 36, "Летопись свободы", {
      fontFamily: "monospace",
      fontSize: "22px",
      color: "#f0d992",
      fontStyle: "bold",
    }).setOrigin(0.5);

    this.add.text(320, 58, "Пролог к битве за демократию", {
      fontFamily: "monospace",
      fontSize: "11px",
      color: "#cab99c",
    }).setOrigin(0.5);

    this.storyText = this.add.text(50, 80, "", {
      fontFamily: "monospace",
      fontSize: "14px",
      color: "#f5ece1",
      lineSpacing: 5,
      wordWrap: { width: 540, useAdvancedWrap: true },
    });

    this.hintText = this.add.text(320, 284, "Клик или пробел ускоряет повествование", {
      fontFamily: "monospace",
      fontSize: "11px",
      color: "#bba789",
    }).setOrigin(0.5);

    this.startButton = this.createStartButton();
    this.startButton.setVisible(false);

    this.typingEvent = this.time.addEvent({
      delay: 32,
      loop: true,
      callback: this.revealNextCharacter,
      callbackScope: this,
    });

    this.input.on("pointerdown", () => {
      SFX.unlock();
      if (!this.finishedTyping) {
        this.finishTyping();
      }
    });

    this.input.keyboard.on("keydown-SPACE", () => {
      SFX.unlock();
      if (!this.finishedTyping) {
        this.finishTyping();
      }
    });
  }

  revealNextCharacter() {
    if (this.currentIndex >= this.fullText.length) {
      this.finishTyping();
      return;
    }

    const nextChar = this.fullText[this.currentIndex];
    this.currentIndex += 1;
    this.storyText.setText(this.fullText.slice(0, this.currentIndex));

    if (nextChar && nextChar.trim() && this.currentIndex % 3 === 0) {
      SFX.typeBlip(this.currentIndex);
    }
  }

  finishTyping() {
    if (this.finishedTyping) {
      return;
    }

    this.finishedTyping = true;
    this.currentIndex = this.fullText.length;
    this.storyText.setText(this.fullText);
    this.typingEvent?.remove(false);
    this.hintText.setText("История записана. Теперь ее надо пережить.");
    this.startButton.setVisible(true);
    SFX.buttonReveal();
    this.tweens.add({
      targets: this.startButton,
      alpha: { from: 0, to: 1 },
      y: this.startButton.y - 6,
      duration: 420,
      ease: "Quad.Out",
    });
  }

  createStartButton() {
    const container = this.add.container(320, 326);
    const glow = this.add.rectangle(0, 0, 282, 38, 0x5e3114, 0.45);
    const base = this.add.rectangle(0, 0, 270, 32, 0x7b2b30)
      .setStrokeStyle(2, 0xf0d992, 1)
      .setInteractive({ useHandCursor: true });
    const label = this.add.text(0, 0, "Защитить демократию!", {
      fontFamily: "monospace",
      fontSize: "17px",
      color: "#fff4d2",
      fontStyle: "bold",
    }).setOrigin(0.5);

    base.on("pointerover", () => {
      base.setFillStyle(0x964445, 1);
      glow.setFillStyle(0x8f5a21, 0.65);
    });

    base.on("pointerout", () => {
      base.setFillStyle(0x7b2b30, 1);
      glow.setFillStyle(0x5e3114, 0.45);
    });

    base.on("pointerdown", () => {
      SFX.unlock().then(() => {
        SFX.buttonClick();
      });
      this.cameras.main.fadeOut(320, 0, 0, 0);
      this.time.delayedCall(340, () => {
        this.scene.start("battle");
      });
    });

    container.add([glow, base, label]);
    container.alpha = 0;
    return container;
  }
}

class BattleScene extends Phaser.Scene {
  constructor() {
    super("battle");
  }

  create() {
    this.selectedType = "chair";
    this.resources = 140;
    this.waveIndex = 0;
    this.pendingSpawns = 0;
    this.victoryTriggered = false;
    this.isFinished = false;
    this.occupiedCells = new Map();
    this.defenders = [];
    this.attackers = [];
    this.projectiles = [];

    this.add.image(320, 180, "background");
    this.add.rectangle(320, 328, 640, 64, 0x110a0c, 0.82)
      .setStrokeStyle(1, 0xe3c26a, 0.26);

    this.drawLaneHints();
    this.createWaves();
    this.createHud();
    this.createObjective();
    this.createPlacementPreview();
    this.createInput();

    this.time.addEvent({
      delay: 2100,
      loop: true,
      callback: () => {
        if (!this.isFinished) {
          this.resources = Math.min(999, this.resources + 18);
          this.updateHud();
        }
      },
    });

    this.time.addEvent({
      delay: 2500,
      callback: this.launchNextWave,
      callbackScope: this,
    });

    this.cameras.main.fadeIn(280, 0, 0, 0);
    this.time.delayedCall(120, () => {
      SFX.battleStart();
    });
  }

  drawLaneHints() {
    this.laneZones = [];
    const graphics = this.add.graphics();
    graphics.lineStyle(1, 0xf0d992, 0.18);

    LANE_Y.forEach((y, lane) => {
      graphics.strokeRoundedRect(128, y - 14, 444, 24, 8);
      const zone = this.add.zone(350, y - 2, 460, 28).setOrigin(0.5);
      zone.setData("lane", lane);
      this.laneZones.push(zone);
    });
  }

  createHud() {
    this.resourceText = this.add.text(622, 309, "", {
      fontFamily: "monospace",
      fontSize: "13px",
      color: "#f0d992",
      fontStyle: "bold",
    }).setOrigin(1, 0);

    this.waveText = this.add.text(622, 326, "", {
      fontFamily: "monospace",
      fontSize: "10px",
      color: "#e8dcc2",
    }).setOrigin(1, 0);

    this.helpText = this.add.text(16, 310, "1: Стул  2: Вайнштейн", {
      fontFamily: "monospace",
      fontSize: "11px",
      color: "#f3e7d4",
    });

    this.helpText2 = this.add.text(16, 326, "Клик по клетке для установки", {
      fontFamily: "monospace",
      fontSize: "10px",
      color: "#f3e7d4",
    });

    this.cardContainer = this.add.container(0, 0);
    this.cards = {
      chair: this.createCard(270, 330, "chair", UNIT_DEFS.chair),
      weinstein: this.createCard(432, 330, "weinstein", UNIT_DEFS.weinstein),
    };

    this.updateHud();
    this.refreshCardSelection();
  }

  createCard(x, y, type, def) {
    const container = this.add.container(x, y);
    const shadow = this.add.rectangle(0, 3, 146, 44, 0x1e0e10, 0.7);
    const base = this.add.rectangle(0, 0, 144, 42, 0x2a1618)
      .setStrokeStyle(1, 0x93734e, 0.7)
      .setInteractive({ useHandCursor: true });
    const icon = this.add.sprite(-50, 0, `${type}_sheet`, 0)
      .setOrigin(0.5, 1)
      .setScale(0.75);
    const name = this.add.text(-20, -9, def.name, {
      fontFamily: "monospace",
      fontSize: "12px",
      color: "#fff2d2",
      fontStyle: "bold",
    });
    const cost = this.add.text(-20, 8, `Цена: ${def.cost}`, {
      fontFamily: "monospace",
      fontSize: "10px",
      color: "#d9c4a5",
    });

    base.on("pointerdown", () => {
      this.selectedType = type;
      this.refreshCardSelection();
    });

    container.add([shadow, base, icon, name, cost]);
    container.base = base;
    container.shadow = shadow;
    container.type = type;
    this.cardContainer.add(container);
    return container;
  }

  createObjective() {
    this.slavyan = this.createUnitSprite({
      x: SLAVYAN_X,
      y: SLAVYAN_Y,
      key: "slavyan",
      name: UNIT_DEFS.slavyan.name,
      hp: UNIT_DEFS.slavyan.hp,
      maxHp: UNIT_DEFS.slavyan.hp,
      team: "objective",
      lane: 1,
      spriteKey: UNIT_DEFS.slavyan.sprite,
    });
    this.slavyan.sprite.play("slavyan-idle");
    this.createSlavyanSpeech();
    this.startSlavyanSlogans();
  }

  createSlavyanSpeech() {
    this.slavyanSloganIndex = 0;
    this.slavyanSpeech = this.add.container(SLAVYAN_X + 108, SLAVYAN_Y - 82)
      .setDepth(9)
      .setAlpha(0);

    const bubble = this.add.ellipse(0, 0, 216, 48, 0x1a0f11, 0.95)
      .setStrokeStyle(2, 0xf0d992, 0.8);
    const tailLarge = this.add.circle(-66, 14, 8, 0x1a0f11, 0.95)
      .setStrokeStyle(2, 0xf0d992, 0.8);
    const tailMid = this.add.circle(-82, 22, 5, 0x1a0f11, 0.95)
      .setStrokeStyle(2, 0xf0d992, 0.8);
    const tailSmall = this.add.circle(-94, 30, 3, 0x1a0f11, 0.95)
      .setStrokeStyle(1, 0xf0d992, 0.8);
    const label = this.add.text(0, 0, "", {
      fontFamily: "monospace",
      fontSize: "10px",
      color: "#fff2d2",
      align: "center",
      wordWrap: { width: 176, useAdvancedWrap: true },
    }).setOrigin(0.5);

    this.slavyanSpeech.add([bubble, tailLarge, tailMid, tailSmall, label]);
    this.slavyanSpeech.bubble = bubble;
    this.slavyanSpeech.tailLarge = tailLarge;
    this.slavyanSpeech.tailMid = tailMid;
    this.slavyanSpeech.tailSmall = tailSmall;
    this.slavyanSpeech.label = label;
  }

  startSlavyanSlogans() {
    this.time.addEvent({
      delay: 6000,
      loop: true,
      callback: () => {
        if (this.isFinished || !this.slavyan?.alive) {
          return;
        }

        this.showSlavyanSlogan();
      },
    });
  }

  showSlavyanSlogan() {
    if (!this.slavyanSpeech) {
      return;
    }

    const slogan = SLAVYAN_SLOGANS[this.slavyanSloganIndex % SLAVYAN_SLOGANS.length];
    this.slavyanSloganIndex += 1;

    this.slavyanSpeech.label.setWordWrapWidth(204, true);
    this.slavyanSpeech.label.setText(slogan);
    const bounds = this.slavyanSpeech.label.getBounds();
    const width = Math.max(168, Math.ceil(bounds.width) + 34);
    const height = Math.max(42, Math.ceil(bounds.height) + 24);

    this.slavyanSpeech.label.setWordWrapWidth(width - 28, true);
    this.slavyanSpeech.bubble.setDisplaySize(width, height);
    this.slavyanSpeech.tailLarge.setPosition((-width * 0.34), (height * 0.28));
    this.slavyanSpeech.tailMid.setPosition((-width * 0.45), (height * 0.43));
    this.slavyanSpeech.tailSmall.setPosition((-width * 0.56), (height * 0.58));
    this.slavyanSpeech.label.setPosition(0, 0);
    this.slavyanSpeech.setAlpha(1);
    this.slavyanSpeech.y = SLAVYAN_Y - 82;

    this.tweens.killTweensOf(this.slavyanSpeech);
    this.tweens.add({
      targets: this.slavyanSpeech,
      alpha: 0,
      y: this.slavyanSpeech.y - 10,
      duration: 4400,
      ease: "Quad.Out",
    });
  }

  createPlacementPreview() {
    this.previewRect = this.add.rectangle(COLUMN_X[0], LANE_Y[0] - 4, 58, 24, GRID_HOVER_COLOR, 0.08)
      .setStrokeStyle(1, GRID_HOVER_COLOR, 0.7)
      .setVisible(false);
  }

  createInput() {
    this.input.keyboard.on("keydown-ONE", () => {
      this.selectedType = "chair";
      this.refreshCardSelection();
    });

    this.input.keyboard.on("keydown-TWO", () => {
      this.selectedType = "weinstein";
      this.refreshCardSelection();
    });

    this.input.on("pointermove", (pointer) => {
      const placement = this.getPlacementAt(pointer.x, pointer.y);
      if (!placement || this.isFinished) {
        this.previewRect.setVisible(false);
        return;
      }

      this.previewRect.setPosition(COLUMN_X[placement.column], LANE_Y[placement.lane] - 4);
      this.previewRect.setVisible(true);
      const occupied = this.isCellOccupied(placement.lane, placement.column);
      this.previewRect.fillColor = occupied ? 0xbf404e : GRID_HOVER_COLOR;
      this.previewRect.strokeColor = occupied ? 0xff7682 : GRID_HOVER_COLOR;
    });

    this.input.on("pointerdown", (pointer) => {
      if (this.isFinished) {
        return;
      }

      const placement = this.getPlacementAt(pointer.x, pointer.y);
      if (!placement) {
        return;
      }

      this.placeDefender(placement.lane, placement.column);
    });
  }

  createWaves() {
    this.waves = [
      [
        { lane: 0, type: "prosecutor", delay: 0 },
        { lane: 1, type: "prosecutor", delay: 2200 },
        { lane: 2, type: "guard", delay: 5200 },
      ],
      [
        { lane: 2, type: "prosecutor", delay: 0 },
        { lane: 1, type: "prosecutor", delay: 1800 },
        { lane: 0, type: "guard", delay: 4200 },
        { lane: 2, type: "prosecutor", delay: 6600 },
        { lane: 1, type: "guard", delay: 9200 },
      ],
      [
        { lane: 2, type: "guard", delay: 0 },
        { lane: 1, type: "prosecutor", delay: 1700 },
        { lane: 0, type: "prosecutor", delay: 3400 },
        { lane: 1, type: "guard", delay: 5600 },
        { lane: 2, type: "prosecutor", delay: 7800 },
        { lane: 2, type: "guard", delay: 10400 },
      ],
      [
        { lane: 0, type: "guard", delay: 0 },
        { lane: 1, type: "guard", delay: 500 },
        { lane: 2, type: "prosecutor", delay: 1000 },
        { lane: 0, type: "prosecutor", delay: 1700 },
        { lane: 2, type: "guard", delay: 2400 },
        { lane: 1, type: "prosecutor", delay: 3200 },
        { lane: 0, type: "guard", delay: 3900 },
        { lane: 2, type: "guard", delay: 4700 },
      ],
    ];
  }

  launchNextWave() {
    if (this.waveIndex >= this.waves.length || this.isFinished) {
      return;
    }

    const waveNumber = this.waveIndex + 1;
    const wave = this.waves[this.waveIndex];
    this.pendingSpawns += wave.length;
    this.waveText.setText(`Волна ${waveNumber} / ${this.waves.length}`);
    this.flashAnnouncement(`Волна ${waveNumber}`);

    wave.forEach((spawnData) => {
      this.time.delayedCall(spawnData.delay, () => {
        if (!this.isFinished) {
          this.spawnAttacker(spawnData.type, spawnData.lane);
        }
        this.pendingSpawns = Math.max(0, this.pendingSpawns - 1);
      });
    });

    const lastDelay = Math.max(...wave.map((entry) => entry.delay));
    this.waveIndex += 1;

    if (this.waveIndex < this.waves.length) {
      const gapAfterWave = POST_WAVE_GAPS[waveNumber - 1] ?? 6200;
      this.time.delayedCall(lastDelay + gapAfterWave, () => this.launchNextWave());
    }
  }

  flashAnnouncement(text) {
    const banner = this.add.text(320, 64, text, {
      fontFamily: "monospace",
      fontSize: "20px",
      color: "#fff2d2",
      backgroundColor: "#5b2025",
      padding: { x: 12, y: 6 },
    }).setOrigin(0.5).setDepth(10);

    this.tweens.add({
      targets: banner,
      alpha: 0,
      y: 48,
      duration: 1800,
      ease: "Quad.Out",
      onComplete: () => banner.destroy(),
    });
  }

  spawnAttacker(type, lane) {
    const def = UNIT_DEFS[type];
    const unit = this.createCombatUnit({
      key: type,
      x: ENEMY_SPAWN_X + Phaser.Math.Between(0, 16),
      y: LANE_Y[lane],
      lane,
      def,
      team: "attackers",
    });

    this.attackers.push(unit);
    unit.sprite.play(`${type}-move`);
  }

  placeDefender(lane, column) {
    const cellKey = `${lane}:${column}`;
    const def = UNIT_DEFS[this.selectedType];

    if (this.resources < def.cost) {
      this.flashAnnouncement("Недостаточно авторитета");
      return;
    }

    if (this.occupiedCells.has(cellKey)) {
      this.flashAnnouncement("Клетка занята");
      return;
    }

    this.resources -= def.cost;
    this.updateHud();

    const unit = this.createCombatUnit({
      key: this.selectedType,
      x: COLUMN_X[column],
      y: LANE_Y[lane],
      lane,
      column,
      def,
      team: "defenders",
    });

    this.occupiedCells.set(cellKey, unit);
    this.defenders.push(unit);
    unit.sprite.play(`${this.selectedType}-idle`);
  }

  createCombatUnit({ key, x, y, lane, column = null, def, team }) {
    const unit = this.createUnitSprite({
      x,
      y,
      key,
      name: def.name,
      hp: def.hp,
      maxHp: def.hp,
      lane,
      team,
      spriteKey: def.sheet,
    });

    unit.column = column;
    unit.damage = def.damage;
    unit.range = def.range;
    unit.cooldown = def.cooldown;
    unit.speed = def.speed;
    unit.attackType = def.attackType;
    unit.projectileSpeed = def.projectileSpeed ?? 0;
    unit.lastAttackAt = 0;
    unit.state = "idle";
    return unit;
  }

  createUnitSprite({ x, y, key, name, hp, maxHp, team, lane, spriteKey }) {
    const container = this.add.container(x, y);
    const sprite = this.add.sprite(0, 0, spriteKey, 0).setOrigin(0.5, 1);
    const nameText = this.add.text(0, -58, name, {
      fontFamily: "monospace",
      fontSize: "9px",
      color: "#fff2d2",
      stroke: "#140b0d",
      strokeThickness: 2,
      align: "center",
    }).setOrigin(0.5, 0.5);
    const hpBg = this.add.rectangle(0, -47, 38, 5, 0x180f12, 0.92)
      .setStrokeStyle(1, 0xe3c26a, 0.45);
    const hpFill = this.add.rectangle(-18, -47, 34, 3, team === "attackers" ? 0xd65f55 : 0x7fd089)
      .setOrigin(0, 0.5);

    container.add([sprite, nameText, hpBg, hpFill]);

    return {
      key,
      x,
      y,
      lane,
      team,
      sprite,
      nameText,
      hpBg,
      hpFill,
      container,
      hp,
      maxHp,
      alive: true,
      hitUntil: 0,
    };
  }

  update(time, delta) {
    const dt = delta / 1000;

    if (this.isFinished) {
      return;
    }

    this.updateProjectiles(dt);
    this.updateDefenders(time, dt);
    this.updateAttackers(time, dt);
    this.cleanupUnits();
    this.updateObjectiveUi();

    if (!this.victoryTriggered &&
        this.waveIndex >= this.waves.length &&
        this.pendingSpawns === 0 &&
        this.attackers.length === 0) {
      this.finishBattle(true);
    }
  }

  updateDefenders(time, dt) {
    this.defenders.forEach((unit) => {
      if (!unit.alive) {
        return;
      }

      const target = this.getNearestAttackerInLane(unit.lane, unit.x, unit.range);
      if (!target) {
        this.setUnitAnim(unit, "idle");
        return;
      }

      if (target.x - unit.x <= unit.range) {
        this.setUnitAnim(unit, "attack");
        this.tryAttack(unit, target, time);
      } else {
        this.setUnitAnim(unit, "idle");
      }
    });
  }

  updateAttackers(time, dt) {
    this.attackers.forEach((unit) => {
      if (!unit.alive) {
        return;
      }

      const defender = this.getNearestDefenderInLane(unit.lane, unit.x, unit.range);
      if (defender) {
        this.setUnitAnim(unit, "attack");
        this.tryAttack(unit, defender, time);
        return;
      }

      const slavyanDistance = unit.x - SLAVYAN_X;
      if (slavyanDistance <= unit.range + 18) {
        this.setUnitAnim(unit, "attack");
        this.tryAttack(unit, this.slavyan, time);
        return;
      }

      unit.x -= unit.speed * dt;
      unit.container.x = unit.x;
      this.setUnitAnim(unit, "move");
    });
  }

  updateProjectiles(dt) {
    this.projectiles = this.projectiles.filter((projectile) => {
      if (!projectile.alive) {
        projectile.rect.destroy();
        return false;
      }

      projectile.x += projectile.speed * dt;
      projectile.rect.x = projectile.x;

      if (!projectile.target.alive) {
        projectile.alive = false;
        projectile.rect.destroy();
        return false;
      }

      if (Phaser.Math.Distance.Between(projectile.x, projectile.y, projectile.target.x, projectile.target.y - 26) < 18) {
        this.applyDamage(projectile.target, projectile.damage);
        projectile.alive = false;
        projectile.rect.destroy();
        return false;
      }

      if (projectile.x > GAME_WIDTH + 20) {
        projectile.alive = false;
        projectile.rect.destroy();
        return false;
      }

      return true;
    });
  }

  tryAttack(unit, target, time) {
    if (time < unit.lastAttackAt + unit.cooldown) {
      return;
    }

    unit.lastAttackAt = time;
    unit.state = "attack";
    unit.sprite.play(`${unit.key}-attack`, true);

    if (unit.attackType === "projectile") {
      const rect = this.add.rectangle(unit.x + 18, unit.y - 28, 10, 6, 0xf4ede2)
        .setStrokeStyle(1, 0x3a5ea0, 1);
      this.projectiles.push({
        rect,
        x: rect.x,
        y: rect.y,
        speed: unit.projectileSpeed,
        damage: unit.damage,
        target,
        alive: true,
      });
      return;
    }

    this.applyDamage(target, unit.damage);
  }

  applyDamage(target, amount) {
    target.hp = Math.max(0, target.hp - amount);
    target.hitUntil = this.time.now + 120;
    target.sprite.play(`${target.key}-hit`, true);

    this.time.delayedCall(130, () => {
      if (!target.alive) {
        return;
      }

      if (target.team === "attackers") {
        this.setUnitAnim(target, "move");
      } else {
        this.setUnitAnim(target, "idle");
      }
    });

    if (target.hp <= 0) {
      this.killUnit(target);
    }
  }

  killUnit(unit) {
    if (!unit.alive) {
      return;
    }

    unit.alive = false;
    unit.container.setAlpha(0.35);

    if (unit.column !== null) {
      this.occupiedCells.delete(`${unit.lane}:${unit.column}`);
    }

    this.tweens.add({
      targets: unit.container,
      alpha: 0,
      y: unit.container.y + 10,
      duration: 260,
      onComplete: () => {
        unit.container.destroy();
      },
    });

    if (unit === this.slavyan) {
      this.finishBattle(false);
    }
  }

  cleanupUnits() {
    this.defenders = this.defenders.filter((unit) => unit.alive);
    this.attackers = this.attackers.filter((unit) => unit.alive);
  }

  updateObjectiveUi() {
    const units = [this.slavyan, ...this.defenders, ...this.attackers];
    units.forEach((unit) => {
      if (!unit.alive) {
        return;
      }

      const ratio = Phaser.Math.Clamp(unit.hp / unit.maxHp, 0, 1);
      unit.hpFill.width = 34 * ratio;
      unit.hpFill.fillColor = ratio > 0.5 ? 0x7fd089 : ratio > 0.25 ? 0xe3c26a : 0xd65f55;

      if (this.time.now < unit.hitUntil) {
        unit.sprite.setTintFill(0xffd0d0);
      } else {
        unit.sprite.clearTint();
      }
    });
  }

  getNearestAttackerInLane(lane, fromX, maxRange) {
    let best = null;
    let bestDistance = Number.POSITIVE_INFINITY;

    this.attackers.forEach((enemy) => {
      if (!enemy.alive || enemy.lane !== lane || enemy.x < fromX) {
        return;
      }

      const distance = enemy.x - fromX;
      if (distance <= maxRange && distance < bestDistance) {
        bestDistance = distance;
        best = enemy;
      }
    });

    return best;
  }

  getNearestDefenderInLane(lane, fromX, maxRange) {
    let best = null;
    let bestDistance = Number.POSITIVE_INFINITY;

    this.defenders.forEach((defender) => {
      if (!defender.alive || defender.lane !== lane || defender.x > fromX) {
        return;
      }

      const distance = fromX - defender.x;
      if (distance <= maxRange && distance < bestDistance) {
        bestDistance = distance;
        best = defender;
      }
    });

    return best;
  }

  setUnitAnim(unit, state) {
    if (!unit.alive || unit.state === state) {
      return;
    }

    unit.state = state;
    unit.sprite.play(`${unit.key}-${state}`, true);
  }

  getPlacementAt(x, y) {
    if (y < 128 || y > HUD_TOP - 8 || x < 140 || x > 560) {
      return null;
    }

    const lane = this.findNearestIndex(LANE_Y, y);
    const column = this.findNearestIndex(COLUMN_X, x);

    if (lane === -1 || column === -1) {
      return null;
    }

    if (Math.abs(LANE_Y[lane] - y) > 20 || Math.abs(COLUMN_X[column] - x) > 32) {
      return null;
    }

    return { lane, column };
  }

  findNearestIndex(values, target) {
    let bestIndex = -1;
    let bestDistance = Number.POSITIVE_INFINITY;

    values.forEach((value, index) => {
      const distance = Math.abs(value - target);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    });

    return bestIndex;
  }

  isCellOccupied(lane, column) {
    return this.occupiedCells.has(`${lane}:${column}`);
  }

  updateHud() {
    this.resourceText.setText(`Авторитет: ${this.resources}`);
    if (this.waveIndex === 0) {
      this.waveText.setText(`Волна 0 / ${this.waves.length}`);
    }

    Object.values(this.cards).forEach((card) => {
      const affordable = this.resources >= UNIT_DEFS[card.type].cost;
      card.alpha = affordable ? 1 : 0.56;
    });
  }

  refreshCardSelection() {
    Object.values(this.cards).forEach((card) => {
      const selected = card.type === this.selectedType;
      card.base.setFillStyle(selected ? 0x5b2025 : 0x2a1618, 1);
      card.base.setStrokeStyle(2, selected ? 0xf0d992 : 0x93734e, selected ? 1 : 0.7);
      card.shadow.setFillStyle(selected ? 0x6a4217 : 0x1e0e10, selected ? 0.85 : 0.7);
    });
  }

  finishBattle(victory) {
    if (this.isFinished) {
      return;
    }

    this.isFinished = true;
    this.victoryTriggered = victory;
    this.previewRect.setVisible(false);

    const overlay = this.add.container(320, 180).setDepth(20);
    const shade = this.add.rectangle(0, 0, 640, 360, 0x050304, 0.76);
    const panel = this.add.rectangle(0, 0, 420, 170, 0x180c0f, 0.96)
      .setStrokeStyle(2, 0xe3c26a, 0.85);
    const title = this.add.text(0, -42, victory ? "Демократия отстояна" : "Славяна увели", {
      fontFamily: "monospace",
      fontSize: "24px",
      color: victory ? "#fff2d2" : "#ffd0d0",
      fontStyle: "bold",
    }).setOrigin(0.5);
    const body = this.add.text(0, 0,
      victory
        ? "Предмет мебели и дальняя поддержка удержали зал.\nБитва прожита заново."
        : "Оборона рухнула. Нужны новые Стулья,\nлучший тайминг и платить больше денег Вайнштейну.",
      {
        fontFamily: "monospace",
        fontSize: "14px",
        color: "#eadfcb",
        align: "center",
        lineSpacing: 6,
      }
    ).setOrigin(0.5);

    const buttonShadow = this.add.rectangle(0, 58, 196, 38, 0x4b3216, 0.5);
    const button = this.add.rectangle(0, 56, 188, 34, 0x7b2b30)
      .setStrokeStyle(2, 0xf0d992, 1)
      .setInteractive({ useHandCursor: true });
    const buttonText = this.add.text(0, 56, "Сыграть еще раз", {
      fontFamily: "monospace",
      fontSize: "16px",
      color: "#fff4d2",
      fontStyle: "bold",
    }).setOrigin(0.5);

    button.on("pointerover", () => button.setFillStyle(0x964445, 1));
    button.on("pointerout", () => button.setFillStyle(0x7b2b30, 1));
    button.on("pointerdown", () => this.scene.restart());

    overlay.add([shade, panel, title, body, buttonShadow, button, buttonText]);
    overlay.alpha = 0;

    this.tweens.add({
      targets: overlay,
      alpha: 1,
      duration: 240,
    });
  }
}

const config = {
  type: Phaser.AUTO,
  width: GAME_WIDTH,
  height: GAME_HEIGHT,
  parent: "game-root",
  backgroundColor: "#090608",
  pixelArt: true,
  scene: [BootScene, IntroScene, BattleScene],
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
};

new Phaser.Game(config);
