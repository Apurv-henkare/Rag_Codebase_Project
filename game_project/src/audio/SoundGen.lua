--[[
    Inflate - SoundGen
    Retro sound effects synthesised at load time (no audio files).

    A sound = list of layers mixed together.
    A layer = list of segments played one after another.
    A segment:
      wave   'square' | 'triangle' | 'sine' | 'saw' | 'noise'
      f0, f1 start / end frequency in Hz (slides linearly; f1 defaults to f0)
      dur    seconds
      vol    0..1
      duty   square pulse width (default 0.5)
      decay  envelope fall-off power (0 = flat, 1 = linear, 2+ = punchy)
      vib, vibDepth  vibrato rate (Hz) and depth (fraction of frequency)
      lowpass  0..1 smoothing for noise (lower = softer hiss)
]]

SoundGen = {}

local RATE = 22050
local msin, mfloor, mmin, mmax = math.sin, math.floor, math.min, math.max
local TWO_PI = math.pi * 2

local function renderLayer(segs)
    local out = {}
    local n = 0
    local phase = 0
    local noiseVal, noiseHold, filtered = 0, 0, 0
    for s = 1, #segs do
        local seg = segs[s]
        local f0 = seg.f0
        local f1 = seg.f1 or f0
        local samples = mfloor(seg.dur * RATE)
        local vol = seg.vol or 0.5
        local duty = seg.duty or 0.5
        local decay = seg.decay or 1
        local attack = mmin(0.005 * RATE, samples * 0.2)
        local lp = seg.lowpass or 1
        for i = 0, samples - 1 do
            local t = i / samples
            local freq = f0 + (f1 - f0) * t
            if seg.vib then
                freq = freq * (1 + msin(TWO_PI * seg.vib * i / RATE) * (seg.vibDepth or 0.03))
            end
            phase = (phase + freq / RATE) % 1

            local v
            local wave = seg.wave
            if wave == 'square' then
                v = phase < duty and 1 or -1
            elseif wave == 'triangle' then
                v = 1 - 4 * math.abs(phase - 0.5)
            elseif wave == 'saw' then
                v = 2 * phase - 1
            elseif wave == 'sine' then
                v = msin(TWO_PI * phase)
            else -- noise: sample-and-hold at `freq`, then optional low-pass
                noiseHold = noiseHold + freq / RATE
                if noiseHold >= 1 then
                    noiseHold = noiseHold - 1
                    noiseVal = love.math.random() * 2 - 1
                end
                filtered = filtered + (noiseVal - filtered) * lp
                v = filtered
            end

            local env = (decay == 0) and 1 or (1 - t) ^ decay
            if i < attack then env = env * (i / attack) end

            n = n + 1
            out[n] = v * env * vol
        end
    end
    return out
end

function SoundGen.make(layers)
    local rendered, length = {}, 0
    for l = 1, #layers do
        rendered[l] = renderLayer(layers[l])
        length = mmax(length, #rendered[l])
    end
    local data = love.sound.newSoundData(length, RATE, 16, 1)
    for i = 1, length do
        local v = 0
        for l = 1, #rendered do v = v + (rendered[l][i] or 0) end
        data:setSample(i - 1, mmax(-1, mmin(1, v)))
    end
    return love.audio.newSource(data, 'static')
end

-- all game sounds
SoundGen.defs = {
    ['bounce'] = {
        {{wave = 'triangle', f0 = 180, f1 = 380, dur = 0.08, vol = 0.6, decay = 2}},
    },
    ['pop'] = {
        {{wave = 'noise', f0 = 9000, f1 = 1200, dur = 0.3, vol = 0.6, decay = 2}},
        {{wave = 'square', f0 = 320, f1 = 50, dur = 0.25, vol = 0.3, duty = 0.25, decay = 1.5}},
    },
    ['pump'] = {
        {{wave = 'square', f0 = 260, f1 = 720, dur = 0.35, vol = 0.25, duty = 0.25,
          decay = 0.6, vib = 18, vibDepth = 0.05}},
    },
    ['leak'] = {
        {{wave = 'noise', f0 = 7000, dur = 0.35, vol = 0.35, decay = 1, lowpass = 0.35}},
    },
    ['gem'] = {
        {{wave = 'square', f0 = 988, dur = 0.05, vol = 0.25, decay = 0},
         {wave = 'square', f0 = 1319, dur = 0.14, vol = 0.25, decay = 1.5}},
    },
    ['break'] = {
        {{wave = 'noise', f0 = 3000, f1 = 400, dur = 0.3, vol = 0.6, decay = 2}},
        {{wave = 'square', f0 = 130, f1 = 45, dur = 0.2, vol = 0.3, decay = 1.5}},
    },
    ['hurt'] = {
        {{wave = 'square', f0 = 420, f1 = 140, dur = 0.16, vol = 0.3, duty = 0.25, decay = 1}},
    },
    ['size-up'] = {
        {{wave = 'triangle', f0 = 200, f1 = 620, dur = 0.16, vol = 0.5, decay = 0.5}},
    },
    ['size-down'] = {
        {{wave = 'triangle', f0 = 620, f1 = 200, dur = 0.16, vol = 0.5, decay = 0.5}},
    },
    ['select'] = {
        {{wave = 'square', f0 = 660, dur = 0.05, vol = 0.2, decay = 1}},
    },
    ['spring'] = {
        {{wave = 'triangle', f0 = 150, f1 = 700, dur = 0.25, vol = 0.5, decay = 0.8,
          vib = 25, vibDepth = 0.08}},
    },
    ['checkpoint'] = {
        {{wave = 'square', f0 = 784, dur = 0.06, vol = 0.22, decay = 0.2},
         {wave = 'square', f0 = 1047, dur = 0.06, vol = 0.22, decay = 0.2},
         {wave = 'square', f0 = 1319, dur = 0.16, vol = 0.22, decay = 1.2}},
    },
    ['key'] = {
        {{wave = 'square', f0 = 1047, dur = 0.06, vol = 0.25, decay = 0},
         {wave = 'square', f0 = 1568, dur = 0.18, vol = 0.25, decay = 1.5}},
        {{wave = 'triangle', f0 = 523, dur = 0.24, vol = 0.3, decay = 1}},
    },
    ['door'] = {
        {{wave = 'noise', f0 = 1500, f1 = 300, dur = 0.25, vol = 0.4, decay = 1.5}},
        {{wave = 'square', f0 = 200, f1 = 100, dur = 0.2, vol = 0.3, duty = 0.25, decay = 1}},
    },
    ['splash'] = {
        {{wave = 'noise', f0 = 5000, f1 = 900, dur = 0.28, vol = 0.45, decay = 1.6, lowpass = 0.45}},
        {{wave = 'sine', f0 = 520, f1 = 160, dur = 0.12, vol = 0.25, decay = 1.5}},
    },
    ['plate'] = {
        {{wave = 'square', f0 = 220, f1 = 110, dur = 0.08, vol = 0.35, duty = 0.25, decay = 1.5}},
        {{wave = 'noise', f0 = 2000, f1 = 500, dur = 0.06, vol = 0.25, decay = 2}},
    },
    ['gate'] = {
        {{wave = 'noise', f0 = 900, f1 = 300, dur = 0.35, vol = 0.35, decay = 0.8, lowpass = 0.3}},
        {{wave = 'square', f0 = 90, f1 = 70, dur = 0.3, vol = 0.2, duty = 0.25, decay = 1}},
    },
    ['flip'] = {
        {{wave = 'square', f0 = 260, f1 = 900, dur = 0.14, vol = 0.3, duty = 0.25, decay = 0.6}},
        {{wave = 'sine', f0 = 900, f1 = 300, dur = 0.18, vol = 0.2, decay = 1}},
    },
    ['roar'] = {
        {{wave = 'saw', f0 = 110, f1 = 55, dur = 0.55, vol = 0.35, decay = 0.8, vib = 9, vibDepth = 0.12}},
        {{wave = 'noise', f0 = 900, f1 = 200, dur = 0.5, vol = 0.3, decay = 1, lowpass = 0.25}},
    },
    ['charge'] = {
        {{wave = 'square', f0 = 300, f1 = 520, dur = 0.12, vol = 0.18, duty = 0.25, decay = 0,
          vib = 30, vibDepth = 0.1},
         {wave = 'square', f0 = 520, f1 = 700, dur = 0.12, vol = 0.18, duty = 0.25, decay = 1}},
    },
    ['swoop'] = {
        {{wave = 'noise', f0 = 1800, f1 = 4500, dur = 0.25, vol = 0.22, decay = 1, lowpass = 0.3}},
        {{wave = 'sine', f0 = 700, f1 = 350, dur = 0.2, vol = 0.12, decay = 1}},
    },
    -- jungle creatures (level 15)
    ['croak'] = {
        {{wave = 'square', f0 = 140, f1 = 110, dur = 0.07, vol = 0.22, duty = 0.3, decay = 0.5},
         {wave = 'square', f0 = 190, f1 = 120, dur = 0.09, vol = 0.22, duty = 0.3, decay = 1.5}},
    },
    ['hiss'] = {
        {{wave = 'noise', f0 = 9000, dur = 0.3, vol = 0.22, decay = 1.2, lowpass = 0.6}},
    },
    ['throw'] = {
        {{wave = 'noise', f0 = 2500, f1 = 5000, dur = 0.12, vol = 0.18, decay = 1, lowpass = 0.4}},
        {{wave = 'triangle', f0 = 300, f1 = 500, dur = 0.1, vol = 0.2, decay = 1}},
    },
    ['thud'] = {
        {{wave = 'noise', f0 = 1500, f1 = 300, dur = 0.12, vol = 0.3, decay = 2, lowpass = 0.5}},
        {{wave = 'triangle', f0 = 160, f1 = 80, dur = 0.1, vol = 0.3, decay = 1.5}},
    },
    ['snap'] = {
        {{wave = 'square', f0 = 900, f1 = 200, dur = 0.06, vol = 0.25, duty = 0.25, decay = 2}},
        {{wave = 'noise', f0 = 4000, f1 = 1500, dur = 0.07, vol = 0.25, decay = 2}},
    },
    ['chomp'] = {
        {{wave = 'noise', f0 = 5000, f1 = 1200, dur = 0.18, vol = 0.3, decay = 1.5, lowpass = 0.5}},
        {{wave = 'square', f0 = 500, f1 = 250, dur = 0.08, vol = 0.18, duty = 0.25, decay = 2}},
    },
    ['tick'] = {
        {{wave = 'square', f0 = 1500, dur = 0.03, vol = 0.2, decay = 2}},
    },
    ['win'] = {
        {{wave = 'square', f0 = 523, dur = 0.1, vol = 0.25, decay = 0.3},
         {wave = 'square', f0 = 659, dur = 0.1, vol = 0.25, decay = 0.3},
         {wave = 'square', f0 = 784, dur = 0.1, vol = 0.25, decay = 0.3},
         {wave = 'square', f0 = 1047, dur = 0.35, vol = 0.25, decay = 1.2}},
        {{wave = 'triangle', f0 = 262, dur = 0.3, vol = 0.3, decay = 0.3},
         {wave = 'triangle', f0 = 392, dur = 0.35, vol = 0.3, decay = 1.2}},
    },
}

-- sound names in a fixed order (used by the art preview)
SoundGen.order = {'bounce', 'pop', 'pump', 'leak', 'gem', 'break', 'hurt',
                  'size-up', 'size-down', 'select', 'win',
                  'spring', 'checkpoint', 'key', 'door', 'splash', 'plate', 'gate', 'tick', 'flip',
                  'roar', 'charge', 'swoop', 'croak', 'hiss', 'throw', 'thud', 'snap', 'chomp'}

function SoundGen.buildAll(target)
    for name, layers in pairs(SoundGen.defs) do
        target[name] = SoundGen.make(layers)
    end
end
