--[[
    LotusHub / modules/Gamemode/Grand Prix/Auto Horse Racing.lua
    Chức năng: Tự động đua ngựa trong Grand Prix (Autopilot đa Map, NoClip, 1000 spd, Watchdog 8s).
    Nguồn: Trích xuất từ raw Grand Prix Autonomous Full-Auto Engine.
]]
local AutoHorseRacing = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

function AutoHorseRacing.Init(ctx, ui)
    local player = Players.LocalPlayer
    local state = ctx.state

    if state.AutoHorseRacing == nil then
        state.AutoHorseRacing = false
    end

    local function log(message)
        print("[LotusHub HorseRacing] " .. message)
    end

    -- ==========================================================
    -- 1. TỌA ĐỘ 3 MAP (RECORDED TRACKS)
    -- ==========================================================
    local RecordedTracks = {
        [1] = {
            Vector3.new(167.53, 702.14, -249.38), Vector3.new(168.15, 701.66, -241.69),
            Vector3.new(169.17, 701.00, -227.81), Vector3.new(169.08, 700.79, -218.50),
            Vector3.new(167.98, 700.43, -200.76), Vector3.new(165.70, 699.37, -186.41),
            Vector3.new(161.35, 697.58, -163.07), Vector3.new(158.32, 697.00, -145.84),
            Vector3.new(157.28, 697.16, -131.90), Vector3.new(157.14, 698.35, -108.45),
            Vector3.new(156.98, 700.91, -76.27),  Vector3.new(156.93, 702.58, -48.01),
            Vector3.new(156.88, 703.01, -29.68),  Vector3.new(157.78, 702.59, -15.49),
            Vector3.new(158.87, 701.78, -3.57),   Vector3.new(158.33, 700.99, 5.41),
            Vector3.new(156.44, 699.65, 19.52),   Vector3.new(152.52, 698.56, 33.11),
            Vector3.new(146.36, 697.36, 49.54),   Vector3.new(139.14, 696.07, 67.02),
            Vector3.new(132.97, 695.32, 78.35),   Vector3.new(125.29, 694.55, 89.39),
            Vector3.new(117.40, 693.73, 98.61),   Vector3.new(109.15, 692.68, 106.38),
            Vector3.new(98.73, 691.16, 112.58),   Vector3.new(86.92, 689.69, 116.51),
            Vector3.new(75.51, 689.88, 119.28),   Vector3.new(63.06, 690.54, 121.78),
            Vector3.new(51.28, 690.39, 123.89),   Vector3.new(38.05, 690.01, 124.67),
            Vector3.new(25.39, 689.23, 124.44),   Vector3.new(13.10, 687.90, 123.91),
            Vector3.new(0.55, 685.67, 123.08),    Vector3.new(-11.55, 684.21, 123.09),
            Vector3.new(-23.84, 682.94, 123.35),  Vector3.new(-36.35, 682.18, 123.84),
            Vector3.new(-49.10, 680.39, 124.31),  Vector3.new(-61.22, 678.49, 124.44),
            Vector3.new(-73.42, 677.61, 123.20),  Vector3.new(-85.33, 676.84, 121.05),
            Vector3.new(-97.55, 676.31, 117.65),  Vector3.new(-110.65, 675.79, 113.16),
            Vector3.new(-122.48, 675.43, 108.99), Vector3.new(-134.48, 675.08, 105.78),
            Vector3.new(-147.21, 673.97, 105.16), Vector3.new(-160.56, 672.66, 106.58),
            Vector3.new(-174.15, 672.35, 106.99), Vector3.new(-186.91, 673.57, 106.73),
            Vector3.new(-198.44, 675.43, 106.34), Vector3.new(-210.79, 677.54, 104.67),
            Vector3.new(-222.14, 679.46, 100.63), Vector3.new(-234.18, 681.70, 94.93),
            Vector3.new(-244.23, 683.68, 88.31),  Vector3.new(-256.47, 686.43, 79.10),
            Vector3.new(-268.81, 689.48, 66.81),  Vector3.new(-278.99, 692.32, 52.33),
            Vector3.new(-287.62, 695.07, 38.56),  Vector3.new(-293.49, 697.36, 21.27),
            Vector3.new(-294.81, 698.61, 3.77),   Vector3.new(-295.22, 699.85, -14.70),
            Vector3.new(-295.60, 701.06, -33.93), Vector3.new(-295.48, 701.90, -48.08),
            Vector3.new(-294.19, 702.46, -60.98), Vector3.new(-292.80, 700.69, -74.13),
            Vector3.new(-291.46, 696.54, -88.58), Vector3.new(-290.33, 692.11, -100.23),
            Vector3.new(-289.01, 687.36, -113.62), Vector3.new(-287.49, 687.64, -127.83),
            Vector3.new(-285.74, 690.57, -143.06), Vector3.new(-283.88, 689.85, -157.05),
            Vector3.new(-281.86, 685.87, -170.71), Vector3.new(-279.76, 678.57, -183.97),
            Vector3.new(-276.81, 674.93, -196.78), Vector3.new(-271.96, 673.68, -209.52),
            Vector3.new(-265.00, 672.35, -225.96), Vector3.new(-258.55, 671.47, -241.07),
            Vector3.new(-251.92, 671.02, -259.52), Vector3.new(-247.01, 671.01, -282.88),
            Vector3.new(-243.63, 671.01, -300.22), Vector3.new(-239.08, 671.01, -317.10),
            Vector3.new(-233.69, 671.01, -334.98), Vector3.new(-227.92, 671.12, -354.35),
            Vector3.new(-223.59, 671.23, -375.62), Vector3.new(-219.38, 671.72, -391.17),
            Vector3.new(-216.38, 673.73, -408.12), Vector3.new(-213.19, 677.31, -427.79),
            Vector3.new(-209.85, 680.90, -448.49), Vector3.new(-206.59, 682.50, -468.67),
            Vector3.new(-198.85, 682.50, -469.97), Vector3.new(-200.28, 682.49, -480.88),
            Vector3.new(-199.73, 682.08, -496.70), Vector3.new(-198.32, 681.29, -512.14),
            Vector3.new(-195.24, 680.10, -529.21), Vector3.new(-191.67, 678.51, -548.34),
            Vector3.new(-188.36, 678.30, -567.84), Vector3.new(-186.46, 676.94, -584.90),
            Vector3.new(-185.89, 675.51, -603.78), Vector3.new(-184.57, 674.43, -621.55),
            Vector3.new(-183.72, 674.00, -639.43), Vector3.new(-182.88, 673.96, -656.88),
            Vector3.new(-181.77, 673.04, -676.45), Vector3.new(-178.68, 672.09, -694.78),
            Vector3.new(-173.55, 670.58, -718.38), Vector3.new(-168.06, 669.27, -744.24),
            Vector3.new(-162.57, 669.00, -773.13), Vector3.new(-158.44, 670.21, -789.67),
            Vector3.new(-155.47, 672.36, -811.72), Vector3.new(-157.12, 672.00, -829.57),
            Vector3.new(-168.05, 671.18, -844.50), Vector3.new(-185.04, 670.52, -858.94),
            Vector3.new(-202.75, 671.72, -873.37), Vector3.new(-218.46, 673.97, -886.09),
            Vector3.new(-234.56, 674.04, -902.06), Vector3.new(-243.05, 673.61, -918.71),
            Vector3.new(-245.04, 673.53, -935.89), Vector3.new(-241.24, 673.75, -951.16),
            Vector3.new(-231.10, 674.15, -963.80), Vector3.new(-216.84, 674.71, -968.86),
            Vector3.new(-200.66, 675.42, -968.17), Vector3.new(-182.69, 676.12, -966.91),
            Vector3.new(-166.31, 676.46, -967.39), Vector3.new(-148.41, 676.86, -971.22),
            Vector3.new(-132.56, 676.93, -977.30), Vector3.new(-118.66, 676.78, -987.82),
            Vector3.new(-105.18, 677.89, -1000.11), Vector3.new(-90.64, 680.28, -1011.42),
            Vector3.new(-76.31, 682.05, -1027.79), Vector3.new(-61.49, 681.98, -1046.30),
            Vector3.new(-47.50, 684.07, -1063.33), Vector3.new(-32.90, 686.00, -1074.09),
            Vector3.new(-17.53, 687.59, -1078.57), Vector3.new(-0.72, 688.77, -1076.49),
            Vector3.new(13.55, 689.13, -1064.21),  Vector3.new(23.43, 689.39, -1044.21),
            Vector3.new(33.00, 690.92, -1023.98),  Vector3.new(44.31, 691.14, -1006.29),
            Vector3.new(59.45, 691.80, -993.20),   Vector3.new(76.25, 694.09, -981.45),
            Vector3.new(96.68, 697.10, -974.30),   Vector3.new(116.51, 698.60, -968.21),
            Vector3.new(137.10, 698.98, -961.67),  Vector3.new(156.29, 697.23, -951.29),
            Vector3.new(173.32, 695.05, -938.33),  Vector3.new(183.95, 692.23, -921.77),
            Vector3.new(192.97, 689.53, -903.52),  Vector3.new(200.06, 688.21, -879.53),
            Vector3.new(203.04, 686.34, -859.15),  Vector3.new(200.94, 683.58, -840.85),
            Vector3.new(197.48, 681.28, -820.58),  Vector3.new(194.06, 681.02, -800.62),
            Vector3.new(190.71, 681.74, -780.99),  Vector3.new(186.87, 684.93, -760.33),
            Vector3.new(180.77, 691.18, -742.64),  Vector3.new(174.56, 702.01, -727.44),
            Vector3.new(172.87, 713.89, -714.62),  Vector3.new(175.04, 724.01, -703.54),
            Vector3.new(180.30, 732.44, -689.90),  Vector3.new(187.55, 738.63, -677.59),
            Vector3.new(201.96, 742.96, -663.97),  Vector3.new(218.13, 738.72, -650.07),
            Vector3.new(229.16, 726.99, -637.15),  Vector3.new(232.71, 711.29, -624.60),
            Vector3.new(227.26, 695.29, -607.90),  Vector3.new(217.18, 685.64, -592.72),
            Vector3.new(205.49, 681.23, -571.62),  Vector3.new(198.88, 680.89, -549.15),
            Vector3.new(197.44, 680.99, -533.10),  Vector3.new(197.65, 680.98, -512.25),
            Vector3.new(197.14, 682.17, -492.58),  Vector3.new(194.64, 685.42, -472.25),
            Vector3.new(191.54, 688.62, -450.67),  Vector3.new(186.21, 690.50, -430.74),
            Vector3.new(180.52, 692.76, -411.41),  Vector3.new(177.31, 695.38, -390.86),
            Vector3.new(176.55, 696.49, -367.12),  Vector3.new(175.83, 698.31, -345.81),
            Vector3.new(173.35, 700.81, -324.39),  Vector3.new(169.76, 702.28, -302.98),
            Vector3.new(166.22, 703.01, -281.58),  Vector3.new(162.77, 702.73, -260.78),
            Vector3.new(159.70, 702.06, -241.29),  Vector3.new(157.52, 701.37, -221.11),
            Vector3.new(155.25, 699.89, -199.27)
        },
        [2] = {
            Vector3.new(150.20, 702.99, -297.33), Vector3.new(156.25, 702.87, -280.83),
            Vector3.new(161.96, 703.34, -265.27), Vector3.new(166.07, 704.21, -249.41),
            Vector3.new(169.19, 705.19, -233.33), Vector3.new(174.99, 706.52, -216.19),
            Vector3.new(181.25, 707.99, -200.43), Vector3.new(187.32, 709.26, -185.21),
            Vector3.new(193.99, 709.98, -168.22), Vector3.new(199.80, 709.58, -151.18),
            Vector3.new(203.61, 708.60, -134.76), Vector3.new(206.88, 707.20, -118.46),
            Vector3.new(210.21, 706.40, -102.35), Vector3.new(213.52, 706.09, -86.17),
            Vector3.new(214.61, 705.78, -73.63),  Vector3.new(213.17, 705.10, -56.81),
            Vector3.new(211.23, 704.68, -40.74),  Vector3.new(207.94, 703.85, -19.76),
            Vector3.new(201.18, 701.82, -5.13),   Vector3.new(191.35, 700.50, 9.79),
            Vector3.new(178.33, 699.54, 25.61),   Vector3.new(164.34, 698.34, 33.95),
            Vector3.new(148.88, 697.11, 39.24),   Vector3.new(133.22, 696.62, 44.28),
            Vector3.new(116.78, 696.16, 51.19),   Vector3.new(101.84, 695.17, 59.11),
            Vector3.new(85.80, 693.52, 67.81),    Vector3.new(67.42, 691.23, 76.57),
            Vector3.new(49.83, 691.42, 78.30),    Vector3.new(32.63, 690.01, 75.49),
            Vector3.new(16.16, 686.51, 70.37),    Vector3.new(0.14, 681.99, 70.53),
            Vector3.new(-15.62, 681.65, 74.92),   Vector3.new(-31.68, 683.71, 80.31),
            Vector3.new(-47.83, 687.66, 84.39),   Vector3.new(-65.05, 686.78, 86.92),
            Vector3.new(-82.65, 685.45, 87.79),   Vector3.new(-99.35, 684.37, 87.45),
            Vector3.new(-116.34, 684.68, 83.01),  Vector3.new(-133.22, 683.05, 74.69),
            Vector3.new(-146.11, 683.01, 64.32),  Vector3.new(-155.69, 683.01, 50.98),
            Vector3.new(-161.77, 683.02, 33.99),  Vector3.new(-163.25, 683.01, 16.93),
            Vector3.new(-160.17, 683.01, -1.18),  Vector3.new(-155.03, 683.06, -16.43),
            Vector3.new(-150.15, 683.24, -36.10), Vector3.new(-149.86, 683.53, -48.86),
            Vector3.new(-150.80, 683.97, -67.37), Vector3.new(-144.25, 685.25, -86.69),
            Vector3.new(-137.47, 685.81, -104.97), Vector3.new(-133.88, 686.13, -124.11),
            Vector3.new(-133.45, 686.30, -139.14), Vector3.new(-142.47, 686.47, -153.07),
            Vector3.new(-150.88, 686.64, -166.64), Vector3.new(-152.15, 686.80, -178.45),
            Vector3.new(-151.87, 686.95, -191.47), Vector3.new(-154.73, 687.17, -206.49),
            Vector3.new(-159.03, 691.88, -222.63), Vector3.new(-162.19, 702.09, -233.66),
            Vector3.new(-163.86, 712.25, -238.67), Vector3.new(-164.83, 723.64, -240.38),
            Vector3.new(-164.84, 731.92, -240.38), Vector3.new(-163.90, 746.29, -242.39),
            Vector3.new(-163.52, 757.05, -247.52), Vector3.new(-163.68, 766.26, -255.52),
            Vector3.new(-164.30, 772.95, -265.76), Vector3.new(-165.38, 776.67, -279.00),
            Vector3.new(-166.45, 776.98, -292.20), Vector3.new(-167.38, 776.99, -304.37),
            Vector3.new(-168.37, 776.99, -317.25), Vector3.new(-169.29, 776.99, -329.21),
            Vector3.new(-170.40, 777.01, -343.84), Vector3.new(-171.19, 776.97, -355.57),
            Vector3.new(-172.01, 777.01, -368.62), Vector3.new(-172.47, 776.88, -381.43),
            Vector3.new(-170.89, 782.35, -400.01), Vector3.new(-168.98, 785.77, -418.31),
            Vector3.new(-167.50, 787.06, -434.62), Vector3.new(-166.62, 786.03, -450.13),
            Vector3.new(-166.44, 783.02, -463.48), Vector3.new(-166.92, 778.22, -476.41),
            Vector3.new(-168.01, 772.23, -488.16), Vector3.new(-171.33, 770.99, -500.38),
            Vector3.new(-180.91, 771.05, -514.66), Vector3.new(-194.71, 771.02, -525.79),
            Vector3.new(-206.69, 771.01, -537.34), Vector3.new(-217.69, 773.89, -550.17),
            Vector3.new(-225.52, 778.90, -559.41), Vector3.new(-232.70, 780.99, -567.91),
            Vector3.new(-240.35, 780.40, -577.31), Vector3.new(-247.91, 776.08, -587.47),
            Vector3.new(-254.25, 768.94, -596.77), Vector3.new(-260.43, 764.96, -607.47),
            Vector3.new(-266.73, 765.05, -622.61), Vector3.new(-271.41, 765.01, -643.10),
            Vector3.new(-275.59, 764.95, -659.36), Vector3.new(-281.98, 764.99, -674.81),
            Vector3.new(-287.98, 771.18, -689.08), Vector3.new(-293.46, 775.30, -704.40),
            Vector3.new(-297.23, 774.56, -715.66), Vector3.new(-300.70, 770.50, -726.26),
            Vector3.new(-303.86, 763.23, -735.84), Vector3.new(-306.67, 752.88, -744.16),
            Vector3.new(-309.73, 748.09, -754.08), Vector3.new(-313.06, 744.22, -765.12),
            Vector3.new(-316.12, 740.73, -775.60), Vector3.new(-318.31, 737.24, -787.80),
            Vector3.new(-318.35, 734.88, -799.33), Vector3.new(-317.13, 733.29, -812.13),
            Vector3.new(-313.61, 733.00, -829.37), Vector3.new(-306.86, 733.02, -845.21),
            Vector3.new(-298.17, 734.09, -858.25), Vector3.new(-286.96, 733.01, -868.49),
            Vector3.new(-270.90, 732.99, -873.67), Vector3.new(-255.31, 733.01, -867.45),
            Vector3.new(-245.24, 732.99, -852.00), Vector3.new(-236.67, 732.94, -835.87),
            Vector3.new(-226.88, 730.77, -818.53), Vector3.new(-217.50, 730.13, -803.03),
            Vector3.new(-208.56, 731.31, -788.82), Vector3.new(-196.89, 733.12, -772.90),
            Vector3.new(-182.94, 734.36, -762.90), Vector3.new(-167.45, 734.94, -758.75),
            Vector3.new(-149.18, 734.59, -758.48), Vector3.new(-132.71, 733.41, -758.59),
            Vector3.new(-115.33, 733.35, -758.93), Vector3.new(-100.69, 738.02, -761.76),
            Vector3.new(-89.01, 747.67, -765.08),  Vector3.new(-81.46, 760.83, -767.60),
            Vector3.new(-78.94, 773.63, -768.90),  Vector3.new(-81.22, 789.82, -769.63),
            Vector3.new(-87.56, 801.36, -771.61),  Vector3.new(-98.79, 811.69, -774.67),
            Vector3.new(-112.17, 817.43, -780.53), Vector3.new(-126.42, 819.25, -787.48),
            Vector3.new(-141.05, 817.26, -793.71), Vector3.new(-154.84, 811.16, -799.39),
            Vector3.new(-166.49, 800.89, -805.16), Vector3.new(-173.91, 788.31, -810.76),
            Vector3.new(-176.92, 772.25, -817.15), Vector3.new(-173.20, 756.26, -821.78),
            Vector3.new(-163.75, 743.28, -826.80), Vector3.new(-150.25, 735.14, -832.70),
            Vector3.new(-134.05, 733.00, -839.33), Vector3.new(-116.90, 732.44, -846.14),
            Vector3.new(-96.50, 730.74, -854.61),  Vector3.new(-78.69, 729.07, -865.48),
            Vector3.new(-65.85, 727.72, -879.60),  Vector3.new(-56.08, 726.92, -894.24),
            Vector3.new(-48.22, 723.82, -913.78),  Vector3.new(-40.40, 720.87, -930.67),
            Vector3.new(-29.68, 718.39, -944.33),  Vector3.new(-16.75, 714.28, -954.95),
            Vector3.new(-1.58, 710.68, -965.37),   Vector3.new(13.33, 710.77, -975.69),
            Vector3.new(30.51, 710.35, -982.66),   Vector3.new(49.02, 712.31, -984.72),
            Vector3.new(67.12, 714.72, -980.76),   Vector3.new(82.08, 715.39, -970.12),
            Vector3.new(89.19, 713.70, -954.44),   Vector3.new(86.90, 709.01, -937.73),
            Vector3.new(77.58, 708.56, -919.84),   Vector3.new(70.54, 710.12, -902.37),
            Vector3.new(63.67, 709.03, -884.34),   Vector3.new(57.22, 708.39, -863.31),
            Vector3.new(54.02, 708.25, -843.12),   Vector3.new(49.72, 708.97, -826.11),
            Vector3.new(48.47, 709.76, -809.57),   Vector3.new(51.00, 710.46, -793.28),
            Vector3.new(55.96, 711.41, -773.03),   Vector3.new(61.38, 712.90, -752.39),
            Vector3.new(67.35, 710.72, -736.82),   Vector3.new(71.13, 708.04, -720.90),
            Vector3.new(72.78, 705.41, -704.92),   Vector3.new(74.23, 704.22, -691.30),
            Vector3.new(75.48, 704.29, -675.17),   Vector3.new(74.90, 705.19, -658.42),
            Vector3.new(72.83, 706.56, -637.81),   Vector3.new(68.19, 708.36, -620.63),
            Vector3.new(60.83, 708.16, -599.91),   Vector3.new(56.65, 706.67, -582.42),
            Vector3.new(58.65, 705.32, -565.72),   Vector3.new(63.39, 703.79, -546.12),
            Vector3.new(67.69, 704.49, -529.36),   Vector3.new(72.08, 705.99, -511.70),
            Vector3.new(76.51, 707.75, -493.59),   Vector3.new(80.50, 707.93, -475.78),
            Vector3.new(84.71, 707.47, -457.18),   Vector3.new(89.94, 708.06, -437.96),
            Vector3.new(97.06, 708.37, -423.98),   Vector3.new(106.47, 708.47, -410.88),
            Vector3.new(118.17, 707.55, -394.77),  Vector3.new(128.96, 705.27, -379.29),
            Vector3.new(137.37, 703.76, -358.33),  Vector3.new(144.83, 703.00, -336.27),
            Vector3.new(153.63, 703.01, -311.93),  Vector3.new(162.98, 702.98, -286.08),
            Vector3.new(168.63, 703.18, -270.51)
        },
        [3] = {
            Vector3.new(154.43, 703.03, -272.66), Vector3.new(151.63, 703.31, -287.45),
            Vector3.new(150.93, 704.72, -303.07), Vector3.new(150.29, 706.59, -322.22),
            Vector3.new(152.04, 706.03, -342.44), Vector3.new(157.70, 703.75, -358.92),
            Vector3.new(163.90, 701.75, -375.79), Vector3.new(170.96, 700.11, -392.67),
            Vector3.new(182.28, 698.21, -410.40), Vector3.new(196.19, 696.26, -423.04),
            Vector3.new(213.98, 694.89, -433.94), Vector3.new(233.00, 692.66, -441.40),
            Vector3.new(253.89, 687.94, -449.33), Vector3.new(274.08, 682.23, -456.48),
            Vector3.new(295.76, 675.50, -461.73), Vector3.new(317.69, 668.52, -464.87),
            Vector3.new(337.95, 662.28, -467.64), Vector3.new(358.18, 656.43, -472.69),
            Vector3.new(377.75, 651.97, -475.43), Vector3.new(397.40, 648.60, -482.30),
            Vector3.new(415.21, 647.09, -492.66), Vector3.new(431.19, 647.22, -500.10),
            Vector3.new(447.09, 647.64, -506.18), Vector3.new(464.26, 647.44, -512.85),
            Vector3.new(481.80, 648.18, -519.62), Vector3.new(498.27, 649.14, -525.91),
            Vector3.new(517.85, 650.36, -533.17), Vector3.new(537.45, 650.55, -539.31),
            Vector3.new(555.52, 650.52, -543.87), Vector3.new(570.22, 650.68, -550.35),
            Vector3.new(580.34, 650.78, -553.71), Vector3.new(596.29, 650.37, -551.53),
            Vector3.new(618.17, 650.39, -552.51), Vector3.new(637.65, 650.06, -551.63),
            Vector3.new(659.17, 649.55, -549.96), Vector3.new(680.79, 649.45, -550.74),
            Vector3.new(700.70, 649.30, -553.04), Vector3.new(719.62, 649.94, -559.37),
            Vector3.new(732.94, 647.94, -567.81), Vector3.new(745.06, 648.27, -581.94),
            Vector3.new(754.28, 647.38, -595.57), Vector3.new(761.34, 647.68, -610.21),
            Vector3.new(767.42, 649.91, -626.53), Vector3.new(770.74, 650.42, -643.17),
            Vector3.new(771.22, 652.63, -661.46), Vector3.new(768.30, 656.59, -681.29),
            Vector3.new(763.57, 658.04, -697.78), Vector3.new(759.80, 657.22, -721.16),
            Vector3.new(764.06, 656.29, -736.17), Vector3.new(758.88, 655.56, -750.90),
            Vector3.new(753.07, 655.15, -765.69), Vector3.new(749.39, 655.06, -781.39),
            Vector3.new(743.51, 655.54, -796.75), Vector3.new(736.63, 656.47, -815.39),
            Vector3.new(729.80, 656.26, -829.42), Vector3.new(721.83, 656.36, -844.58),
            Vector3.new(709.28, 656.95, -859.62), Vector3.new(692.29, 656.98, -868.55),
            Vector3.new(673.38, 657.20, -873.74), Vector3.new(654.83, 657.60, -875.14),
            Vector3.new(634.71, 658.77, -874.95), Vector3.new(617.27, 660.02, -869.53),
            Vector3.new(602.31, 661.50, -861.57), Vector3.new(589.62, 663.02, -851.10),
            Vector3.new(579.92, 663.98, -836.22), Vector3.new(573.78, 664.04, -818.54),
            Vector3.new(565.85, 664.77, -801.88), Vector3.new(553.26, 666.88, -788.48),
            Vector3.new(539.53, 666.13, -778.43), Vector3.new(523.50, 666.52, -772.99),
            Vector3.new(504.82, 666.99, -775.45), Vector3.new(489.06, 665.55, -781.58),
            Vector3.new(475.17, 664.53, -794.92), Vector3.new(464.96, 663.74, -809.66),
            Vector3.new(454.71, 663.99, -829.70), Vector3.new(445.01, 666.37, -845.77),
            Vector3.new(435.52, 667.45, -862.23), Vector3.new(425.95, 668.13, -883.58),
            Vector3.new(420.05, 668.88, -905.53), Vector3.new(414.53, 669.56, -927.13),
            Vector3.new(406.98, 669.92, -943.10), Vector3.new(396.50, 669.90, -956.66),
            Vector3.new(383.30, 669.67, -966.47), Vector3.new(368.98, 671.43, -972.00),
            Vector3.new(359.16, 671.42, -981.47), Vector3.new(352.98, 673.29, -990.22),
            Vector3.new(342.56, 672.71, -985.88), Vector3.new(332.30, 672.15, -974.10),
            Vector3.new(322.06, 672.15, -960.78), Vector3.new(310.51, 672.97, -942.19),
            Vector3.new(306.23, 672.87, -924.52), Vector3.new(303.11, 671.86, -904.24),
            Vector3.new(298.72, 674.01, -887.59), Vector3.new(290.57, 678.25, -872.05),
            Vector3.new(279.95, 682.81, -860.13), Vector3.new(266.88, 688.04, -849.90),
            Vector3.new(251.59, 693.10, -843.24), Vector3.new(237.86, 696.85, -842.16),
            Vector3.new(222.42, 700.65, -844.49), Vector3.new(206.95, 704.26, -849.62),
            Vector3.new(190.89, 707.62, -859.35), Vector3.new(179.71, 709.61, -873.42),
            Vector3.new(175.87, 710.07, -885.84), Vector3.new(174.50, 710.11, -899.02),
            Vector3.new(173.92, 711.34, -911.55), Vector3.new(175.42, 714.91, -929.21),
            Vector3.new(182.97, 718.02, -942.91), Vector3.new(196.80, 720.92, -953.24),
            Vector3.new(210.50, 724.35, -959.34), Vector3.new(225.89, 728.59, -962.83),
            Vector3.new(241.18, 733.27, -963.77), Vector3.new(255.53, 737.23, -959.73),
            Vector3.new(268.01, 740.42, -949.72), Vector3.new(278.83, 743.72, -936.94),
            Vector3.new(288.03, 746.65, -922.59), Vector3.new(298.70, 748.34, -902.47),
            Vector3.new(309.40, 749.73, -888.47), Vector3.new(322.04, 750.87, -878.85),
            Vector3.new(335.45, 752.23, -870.86), Vector3.new(348.49, 753.42, -861.21),
            Vector3.new(359.05, 752.97, -848.29), Vector3.new(368.49, 752.08, -834.88),
            Vector3.new(378.54, 751.77, -820.50), Vector3.new(387.25, 752.08, -807.89),
            Vector3.new(398.25, 753.06, -787.99), Vector3.new(402.27, 753.70, -775.03),
            Vector3.new(401.50, 754.06, -758.03), Vector3.new(392.90, 753.41, -744.43),
            Vector3.new(378.48, 752.34, -734.28), Vector3.new(364.72, 752.75, -726.63),
            Vector3.new(352.92, 753.77, -712.58), Vector3.new(348.71, 753.40, -693.13),
            Vector3.new(349.42, 752.68, -669.06), Vector3.new(348.57, 752.68, -652.37),
            Vector3.new(349.31, 753.00, -636.34), Vector3.new(352.95, 753.01, -619.48),
            Vector3.new(357.04, 753.01, -603.52), Vector3.new(361.60, 753.04, -585.48),
            Vector3.new(364.70, 753.30, -565.56), Vector3.new(363.52, 753.34, -548.19),
            Vector3.new(358.25, 751.12, -529.98), Vector3.new(350.81, 744.05, -516.20),
            Vector3.new(346.08, 734.51, -507.05), Vector3.new(344.74, 724.46, -499.01),
            Vector3.new(346.44, 714.87, -491.51), Vector3.new(351.43, 704.39, -484.42),
            Vector3.new(359.39, 695.71, -479.79), Vector3.new(372.01, 688.57, -476.11),
            Vector3.new(385.28, 686.92, -474.03), Vector3.new(398.52, 689.99, -472.51),
            Vector3.new(413.48, 701.86, -470.63), Vector3.new(419.17, 713.59, -468.86),
            Vector3.new(420.79, 725.79, -465.03), Vector3.new(418.83, 737.15, -457.73),
            Vector3.new(415.28, 744.04, -448.14), Vector3.new(411.58, 748.74, -434.86),
            Vector3.new(408.66, 751.08, -424.33), Vector3.new(405.28, 752.76, -411.70),
            Vector3.new(401.94, 753.55, -399.48), Vector3.new(400.02, 753.60, -387.73),
            Vector3.new(399.63, 753.30, -375.74), Vector3.new(401.47, 753.07, -363.84),
            Vector3.new(404.63, 753.01, -352.13), Vector3.new(407.94, 753.01, -340.48),
            Vector3.new(411.27, 753.01, -328.79), Vector3.new(414.59, 753.01, -317.12),
            Vector3.new(417.88, 753.01, -305.50), Vector3.new(420.62, 752.93, -293.25),
            Vector3.new(422.67, 753.01, -281.03), Vector3.new(425.02, 752.97, -266.38),
            Vector3.new(427.00, 753.01, -254.42), Vector3.new(429.74, 753.01, -242.91),
            Vector3.new(432.90, 753.01, -231.61), Vector3.new(436.24, 755.82, -219.92),
            Vector3.new(439.70, 761.04, -207.72), Vector3.new(443.16, 763.43, -195.42),
            Vector3.new(446.54, 762.59, -183.52), Vector3.new(449.78, 758.45, -172.34),
            Vector3.new(452.88, 750.70, -161.96), Vector3.new(455.27, 740.66, -153.54),
            Vector3.new(457.37, 734.25, -143.50), Vector3.new(457.96, 730.91, -130.16),
            Vector3.new(456.69, 727.22, -117.82), Vector3.new(453.45, 722.64, -104.27),
            Vector3.new(449.77, 719.25, -93.74),  Vector3.new(444.09, 715.38, -82.18),
            Vector3.new(437.69, 712.20, -71.87),  Vector3.new(429.61, 709.34, -61.89),
            Vector3.new(420.08, 707.00, -54.17),  Vector3.new(408.32, 704.98, -48.49),
            Vector3.new(395.44, 703.76, -44.05),  Vector3.new(383.92, 703.21, -40.78),
            Vector3.new(371.26, 703.17, -37.76),  Vector3.new(359.33, 703.08, -37.20),
            Vector3.new(345.68, 702.63, -40.01),  Vector3.new(333.62, 702.41, -44.06),
            Vector3.new(322.30, 702.34, -49.27),  Vector3.new(312.03, 702.22, -58.18),
            Vector3.new(302.11, 702.44, -66.50),  Vector3.new(292.38, 702.20, -75.61),
            Vector3.new(283.49, 701.62, -84.35),  Vector3.new(274.00, 700.95, -93.75),
            Vector3.new(264.43, 700.17, -103.24), Vector3.new(256.03, 699.62, -111.99),
            Vector3.new(245.95, 698.90, -123.08), Vector3.new(235.31, 698.44, -133.73),
            Vector3.new(225.84, 698.13, -143.64), Vector3.new(217.81, 697.99, -152.63),
            Vector3.new(209.25, 698.84, -162.43), Vector3.new(200.35, 701.25, -172.68),
            Vector3.new(191.07, 702.79, -184.77), Vector3.new(184.45, 702.51, -196.56),
            Vector3.new(180.33, 702.46, -207.84), Vector3.new(176.87, 702.77, -219.56),
            Vector3.new(173.03, 702.99, -234.40), Vector3.new(171.21, 703.01, -245.91),
            Vector3.new(169.48, 703.01, -259.01), Vector3.new(167.71, 702.97, -272.98),
            Vector3.new(165.91, 703.16, -287.35), Vector3.new(164.31, 704.06, -300.16),
            Vector3.new(163.18, 705.09, -309.17)
        }
    }

    local session = {
        currentMap = 1,
        currentIndex = 1,
        lapCount = 1,
        speed = 1000,
        mapCooldownUntil = 0,
        lastProgressIndex = 1,
        lastProgressTime = tick(),
    }

    local function getActiveEntity()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.SeatPart then
            local seat = humanoid.SeatPart
            local vehicleModel = seat:FindFirstAncestorWhichIsA("Model")
            if vehicleModel then
                return vehicleModel, (vehicleModel.PrimaryPart or seat)
            end
            return seat, seat
        end
        return character, rootPart
    end

    local function applyNoClip(model)
        if not model then return end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- ==========================================================
    -- 2. DÒ MAP VÀ CHUYỂN MAP LIÊN TỤC
    -- ==========================================================
    task.spawn(function()
        local lastWorldCheck = 0
        local lastRoadInstance = nil
        local lastChildCount = -1

        local function triggerNextMap(targetMap)
            if tick() - lastWorldCheck < 4.0 then return end
            lastWorldCheck = tick()

            if targetMap then
                session.currentMap = targetMap
            else
                session.currentMap = (session.currentMap % 3) + 1
            end

            session.currentIndex = 1
            session.lapCount = 1
            session.mapCooldownUntil = tick() + 10
            session.lastProgressIndex = 1
            session.lastProgressTime = tick()
            log(string.format("Chuyển sang MAP %d -> Chờ 10s nạp asset!", session.currentMap))
        end

        while ctx.alive do
            task.wait(0.3)
            if state.AutoHorseRacing == true then
                local gpWorld = Workspace:FindFirstChild("GrandPrixWorld")
                if gpWorld then
                    local road = gpWorld:FindFirstChild("Road")
                    local scenery = gpWorld:FindFirstChild("Scenery")

                    if road and road ~= lastRoadInstance then
                        if lastRoadInstance ~= nil then
                            triggerNextMap()
                        end
                        lastRoadInstance = road
                    end

                    if road then
                        local currentCount = #road:GetChildren() + (scenery and #scenery:GetChildren() or 0)
                        if lastChildCount ~= -1 and math.abs(currentCount - lastChildCount) >= 8 then
                            triggerNextMap()
                        end
                        lastChildCount = currentCount
                    end
                else
                    lastRoadInstance = nil
                    lastChildCount = -1
                end
            end
        end
    end)

    -- ==========================================================
    -- 3. VÒNG LẶP AUTOPILOT (ĐUA NGỰA VƯỢT ĐỊA HÌNH)
    -- ==========================================================
    task.spawn(function()
        log("Lõi Auto Horse Racing sẵn sàng...")

        while ctx.alive do
            if state.AutoHorseRacing == true then
                -- 1. Chờ nạp map nếu vừa đổi
                if tick() < session.mapCooldownUntil then
                    local entity, root = getActiveEntity()
                    if root and root.Parent then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                    RunService.Heartbeat:Wait()
                    continue
                end

                local track = RecordedTracks[session.currentMap]
                if track and #track > 2 then
                    local entity, root = getActiveEntity()
                    if root and root.Parent then
                        applyNoClip(entity)
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero

                        -- 2. Watchdog: Nếu kẹt 8s tại 1 waypoint thì reset về Waypoint 1
                        if session.currentIndex == session.lastProgressIndex then
                            if tick() - session.lastProgressTime >= 8.0 then
                                log(string.format("Kẹt tại Waypoint %d quá 8s! Reset về điểm 1...", session.currentIndex))
                                session.currentIndex = 1
                                session.lastProgressIndex = 1
                                session.lastProgressTime = tick()

                                local p1 = track[1]
                                local p2 = track[2] or (p1 + Vector3.new(0, 0, 1))
                                local resetCF = CFrame.lookAt(p1, p2)
                                if entity:IsA("Model") then
                                    entity:PivotTo(resetCF)
                                else
                                    root.CFrame = resetCF
                                end
                                task.wait(0.1)
                            end
                        else
                            session.lastProgressIndex = session.currentIndex
                            session.lastProgressTime = tick()
                        end

                        -- 3. Di chuyển CFrame mượt mà
                        local dt = RunService.Heartbeat:Wait()
                        local remainingDist = session.speed * dt
                        local currentPos = root.Position
                        local forwardDir = root.CFrame.LookVector

                        while remainingDist > 0 and state.AutoHorseRacing == true and (tick() >= session.mapCooldownUntil) do
                            local targetPt = track[session.currentIndex]
                            local delta = targetPt - currentPos
                            local dist = delta.Magnitude

                            if dist > 0.01 then
                                forwardDir = delta.Unit
                            end

                            if dist <= remainingDist then
                                remainingDist = remainingDist - dist
                                currentPos = targetPt
                                session.currentIndex = session.currentIndex + 1

                                if session.currentIndex > #track then
                                    session.currentIndex = 1
                                    session.lapCount = session.lapCount + 1
                                    log(string.format("Hoàn thành Map %d Vòng %d!", session.currentMap, session.lapCount - 1))
                                end
                            else
                                currentPos = currentPos + (delta.Unit * remainingDist)
                                remainingDist = 0
                            end
                        end

                        local finalCF = CFrame.lookAt(currentPos, currentPos + forwardDir)
                        if entity:IsA("Model") then
                            entity:PivotTo(finalCF)
                        else
                            root.CFrame = finalCF
                        end
                    else
                        task.wait(0.2)
                    end
                else
                    task.wait(0.5)
                end
            else
                task.wait(0.3)
            end
        end
        log("Worker AutoHorseRacing đã dừng an toàn do ctx.alive = false.")
    end)

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoHorseRacing", function(enabled)
            log("AutoHorseRacing = " .. tostring(enabled))
            if enabled then
                session.currentIndex = 1
                session.lastProgressTime = tick()
                session.mapCooldownUntil = tick() + 2
            end
        end)
    end
end

return AutoHorseRacing