-- FearX-Hopouts — map pool
--
-- Each map is one "hop out": two spawn clusters facing each other with a storm
-- circle centred between them. Set enabled = false to pull one out of rotation.
--   storm.center / storm.radius  the starting play area (shrink phases live in config.lua)
--   red / blue .spawns           up to 5 spawn points per side, one per party slot
--   red / blue .vehicles         staged cars, spawned fresh each round

Config.Maps = {
    {
        id = 'little-seoul',
        name = 'Little Seoul',
        enabled = true,
        storm = { center = vector3(-704.27, -897.34, 31.35), radius = 300 },
        red = {
            spawns = {
                vector4(-851.35, -1155.74, 5.18, 299.63),
                vector4(-850.19, -1157.82, 5.17, 299.63),
                vector4(-849.08, -1159.8, 5.16, 299.63),
                vector4(-852.55, -1153.81, 5.15, 299.63),
                vector4(-853.81, -1151.64, 5.12, 299.63)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(-846.95, -1153.24, 6.44, 299.63), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(-845.26, -1156.26, 6.42, 299.63), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-848.85, -1150.14, 6.4, 299.63), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(-627.05, -608.63, 32.35, 180.28),
                vector4(-629.29, -608.63, 32.35, 180.28),
                vector4(-631.79, -608.62, 32.35, 180.28),
                vector4(-624.72, -608.52, 32.31, 180.28),
                vector4(-622.54, -608.5, 32.19, 180.28)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(-627.07, -614.37, 33.04, 179.54), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-630.44, -614.32, 33.04, 179.54), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-623.71, -614.31, 32.94, 179.54), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'morningwood',
        name = 'Morningwood',
        enabled = true,
        storm = { center = vector3(-1525.55, -381.12, 42.51), radius = 275 },
        red = {
            spawns = {
                vector4(-1785.53, -468.91, 39.34, 223.14),
                vector4(-1783.6, -467.15, 39.49, 225.01),
                vector4(-1781.42, -465.28, 39.66, 227.8),
                vector4(-1779.62, -463.48, 39.84, 224.52),
                vector4(-1777.43, -461.08, 39.92, 230.44)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(-1777.56, -468.59, 40.4, 226.22), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(-1780.45, -471.5, 40.12, 224.89), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-1774.92, -464.99, 40.72, 228.51), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(-1258.48, -314.78, 36.16, 111.78),
                vector4(-1259.45, -312.36, 36.12, 109.76),
                vector4(-1260.39, -309.91, 35.96, 113.16),
                vector4(-1257.65, -317.37, 36.16, 113.4),
                vector4(-1256.47, -319.99, 36.16, 117.02)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(-1263.41, -317.12, 37.04, 113.5), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-1264.92, -313.66, 36.92, 114.37), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-1261.58, -320.97, 37.04, 115.21), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'pink-cage',
        name = 'Pink Cage',
        enabled = true,
        storm = { center = vector3(317.51, -254.09, 79.22), radius = 550 },
        red = {
            spawns = {
                vector4(532.51, 76.97, 95.39, 67.2),
                vector4(533.55, 79.44, 95.38, 68.56),
                vector4(534.67, 82.1, 95.38, 63.1),
                vector4(531.6, 74.6, 95.38, 65.66),
                vector4(531.19, 72.13, 95.35, 60.43)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(527.3, 74.53, 96.36, 69.18), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(530.75, 82.04, 96.38, 66.13), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(529.22, 77.92, 96.39, 68.8), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(-56.54, -116.33, 56.95, 244.63),
                vector4(-57.64, -119.37, 56.95, 240.51),
                vector4(-55.74, -113.55, 56.95, 240.17),
                vector4(-55.07, -110.54, 56.94, 232.65),
                vector4(-58.89, -122.16, 56.94, 243.2)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(-55.31, -121.92, 57.94, 244.85), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-53.38, -117.65, 57.95, 244.35), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-51.66, -112.68, 57.95, 245.67), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'mirror-park',
        name = 'Mirror Park',
        enabled = true,
        storm = { center = vector3(1108.46, -593.26, 60), radius = 350 },
        red = {
            spawns = {
                vector4(970.61, -292.03, 66.02, 235.56),
                vector4(969.5, -293.83, 65.96, 226.33),
                vector4(968.25, -295.86, 65.89, 233.44),
                vector4(971.82, -289.71, 65.97, 246.88),
                vector4(973.22, -287.43, 65.9, 234.63)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(975.71, -290.56, 66.91, 235.53), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(973.6, -293.73, 67.02, 237.46), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(971.42, -297.28, 66.87, 239.16), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(1164.95, -869.59, 53.02, 343.23),
                vector4(1167.5, -870.2, 52.99, 342.99),
                vector4(1170.06, -870.68, 52.95, 346),
                vector4(1162.13, -868.83, 53.05, 2.33),
                vector4(1159.13, -868.26, 53.08, 347.82)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(1161.74, -864.76, 54.16, 343.97), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1165.9, -865.91, 54.11, 343.99), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1169.84, -866.66, 54.07, 347.49), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'rockford',
        name = 'Rockford',
        enabled = true,
        storm = { center = vector3(-587.91, -246.62, 36.2), radius = 400 },
        red = {
            spawns = {
                vector4(-628.81, -506.9, 33.81, 359.6),
                vector4(-626.14, -506.94, 33.81, 359.6),
                vector4(-623.89, -506.97, 33.78, 359.6),
                vector4(-631.66, -506.99, 33.82, 359.6),
                vector4(-633.56, -506.99, 33.82, 359.6)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(-628.75, -501.13, 34.81, 358.96), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(-624.88, -501.23, 34.79, 358.96), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-632.14, -501.16, 34.81, 358.96), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(-553.39, 16.11, 43.41, 171.45),
                vector4(-556.64, 16.63, 43.36, 171.45),
                vector4(-559.17, 17.03, 43.29, 171.45),
                vector4(-550.58, 15.81, 43.36, 171.45),
                vector4(-548.19, 15.47, 43.35, 171.45)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(-554.21, 11.01, 44.32, 171.45), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-558.43, 11.68, 44.26, 171.45), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-550.34, 10.53, 44.32, 171.45), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'sandy-shores',
        name = 'Sandy Shores',
        enabled = true,
        storm = { center = vector3(1856.21, 3726.14, 33.15), radius = 600 },
        red = {
            spawns = {
                vector4(2106.6, 3751.91, 32, 113.67),
                vector4(2107.41, 3749.64, 32.02, 114.84),
                vector4(2108.7, 3747.09, 32.04, 119.22),
                vector4(2109.52, 3745.08, 32.03, 113.72),
                vector4(2110.38, 3742.86, 32.02, 120.02)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(2104.47, 3744.97, 33.03, 114.87), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(2105.88, 3741.63, 33.02, 117.69), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(2102.23, 3748.33, 33, 113.7), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(1586.66, 3668.98, 33.46, 295.99),
                vector4(1587.75, 3667.09, 33.48, 291.26),
                vector4(1589.04, 3664.42, 33.51, 296.5),
                vector4(1590.04, 3662.59, 33.49, 293.74),
                vector4(1591.27, 3660.35, 33.47, 298.7)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(1593.46, 3666.81, 34.51, 298.38), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1595.16, 3663.91, 34.48, 293.15), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1591.65, 3669.95, 34.48, 295.5), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'southside',
        name = 'Southside',
        enabled = true,
        storm = { center = vector3(61.16, -1507.66, 29.34), radius = 385 },
        red = {
            spawns = {
                vector4(-313.63, -1428.76, 30.19, 269.63),
                vector4(-313.69, -1432.29, 30.2, 269.63),
                vector4(-313.72, -1434.41, 30.2, 269.63),
                vector4(-313.73, -1425.9, 30.18, 269.63),
                vector4(-313.74, -1423.5, 30.18, 269.63)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(-307.76, -1428.8, 31.31, 269.24), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(-307.86, -1433.26, 31.33, 269.24), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-307.81, -1424.84, 31.3, 269.24), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(355.66, -1735.28, 28.29, 50.81),
                vector4(357.26, -1733.35, 28.28, 50.81),
                vector4(358.76, -1731.55, 28.22, 50.81),
                vector4(353.88, -1737.63, 28.28, 50.81),
                vector4(352.25, -1739.66, 28.24, 50.81)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(350.65, -1731.14, 29.42, 49.66), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(353.06, -1728.35, 29.25, 49.66), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(348.09, -1734.3, 29.31, 49.66), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'paleto-bay',
        name = 'Paleto Bay',
        enabled = true,
        storm = { center = vector3(-59.97, 6474.64, 31.44), radius = 275 },
        red = {
            spawns = {
                vector4(-281.6, 6374.35, 29.53, 294.59),
                vector4(-282.72, 6377.46, 29.64, 292.64),
                vector4(-283.51, 6379.36, 29.66, 292.05),
                vector4(-284.43, 6380.96, 29.62, 290.16),
                vector4(-285.56, 6383.22, 29.53, 293.45)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(-280.88, 6384.1, 30.63, 296.3), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(-279.71, 6381.07, 30.7, 294.23), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-277.96, 6377.91, 30.63, 294.18), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(199.02, 6560.56, 31.01, 107.89),
                vector4(199.52, 6558.09, 30.97, 108.72),
                vector4(200.34, 6555.87, 30.94, 110.05),
                vector4(201.23, 6553.4, 30.93, 109.18),
                vector4(202.31, 6550.39, 30.9, 111.46)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(195.27, 6553.86, 32.12, 110.98), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(194.02, 6557.33, 32, 110.22), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(196.89, 6549.5, 31.91, 111.08), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'la-puerta',
        name = 'La Puerta',
        enabled = true,
        storm = { center = vector3(-1205.14, -1210.77, 7.76), radius = 400 },
        red = {
            spawns = {
                vector4(-1142.55, -824.71, 13.94, 130.45),
                vector4(-1143.86, -823.15, 13.93, 130.45),
                vector4(-1145.13, -821.63, 13.92, 130.45),
                vector4(-1146.38, -820.15, 13.92, 130.45),
                vector4(-1147.71, -818.56, 13.91, 130.45)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(-1147.63, -827.66, 14.65, 129.95), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(-1150.15, -825.13, 14.62, 128.48), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-1153.43, -822.53, 14.57, 126.24), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(-1161.42, -1590.55, 3.36, 306.07),
                vector4(-1160.24, -1592.19, 3.36, 306.07),
                vector4(-1159.21, -1593.64, 3.36, 306.07),
                vector4(-1158.11, -1595.17, 3.36, 306.07),
                vector4(-1156.93, -1596.81, 3.37, 306.07)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(-1156.52, -1588.57, 4.34, 303.99), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-1154.22, -1591.47, 4.42, 303.99), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(-1151.81, -1594.44, 4.25, 303.99), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'industrial',
        name = 'Industrial',
        enabled = true,
        storm = { center = vector3(960.18, -2159.43, 31), radius = 500 },
        red = {
            spawns = {
                vector4(624.39, -2491.1, 16.1, 275.34),
                vector4(624.56, -2493.08, 16.1, 275.34),
                vector4(624.73, -2495.11, 16.1, 275.34),
                vector4(624.92, -2497.33, 16.1, 275.34),
                vector4(625.16, -2500.04, 16.14, 275.34)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(628.73, -2491.32, 17.16, 274.54), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(629.04, -2495.68, 17.13, 274.54), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(629.35, -2500.04, 17.13, 274.54), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(1130.04, -1738.41, 34.61, 110.69),
                vector4(1129.08, -1735.83, 34.68, 110.69),
                vector4(1128.26, -1733.59, 34.72, 110.69),
                vector4(1127.37, -1731.18, 34.75, 110.69),
                vector4(1126.33, -1728.35, 34.74, 110.69)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(1124.92, -1738.84, 35.68, 109.3), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1123.88, -1735.76, 35.69, 109.3), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1122.45, -1731.57, 35.71, 109.3), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'barrios',
        name = 'Barrios',
        enabled = true,
        storm = { center = vector3(268.11, -1837.38, 26.77), radius = 375 },
        red = {
            spawns = {
                vector4(430.28, -2018.06, 22.1, 43.3),
                vector4(431.64, -2016.8, 22.16, 43.3),
                vector4(433.01, -2015.53, 22.19, 43.3),
                vector4(434.44, -2014.2, 22.19, 43.3),
                vector4(436.07, -2012.69, 22.2, 43.3)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(426.75, -2013.34, 23.12, 41.36), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(429.35, -2011.08, 23.18, 41.36), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(432.39, -2008.44, 23.2, 41.36), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(285.63, -1470.04, 28.25, 230.25),
                vector4(284.33, -1471.59, 28.31, 230.25),
                vector4(283.02, -1473.13, 28.34, 230.25),
                vector4(281.61, -1474.8, 28.34, 230.25),
                vector4(280.22, -1476.45, 28.34, 230.25)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(287.9, -1472.79, 29.27, 229.78), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(285.89, -1475.13, 29.34, 229.78), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(283.28, -1478.17, 29.34, 229.78), livery = 8, colors = { 111, 0 } }
            }
        }
    },
    {
        id = 'cypress',
        name = 'Cypress',
        enabled = true,
        storm = { center = vector3(969.68, -1915.13, 41.95), radius = 667 },
        red = {
            spawns = {
                vector4(416.56, -2066.76, 21.51, 142.94),
                vector4(414.97, -2065.39, 21.48, 138.46),
                vector4(413.5, -2064.2, 21.46, 146.14),
                vector4(412.11, -2063.09, 21.44, 147),
                vector4(410.2, -2061.53, 21.41, 137.4)
            },
            vehicles = {
                { model = 'elegy', pos = vector4(407.31, -2076.78, 21.39, 264.56), livery = 7, colors = { 111, 0 } },
                { model = 'buffalo4', pos = vector4(406.93, -2072.8, 21.39, 264.56), livery = 2, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(406.55, -2068.81, 21.39, 264.56), livery = 7, colors = { 111, 0 } }
            }
        },
        blue = {
            spawns = {
                vector4(1547.06, -2174.5, 77.38, 113.39),
                vector4(1546.64, -2177.67, 77.35, 79.48),
                vector4(1546.79, -2172.05, 77.43, 77.61),
                vector4(1546.42, -2168.76, 77.48, 79.25),
                vector4(1545.98, -2181.04, 77.34, 77.11)
            },
            vehicles = {
                { model = 'buffalo4', pos = vector4(1536.46, -2185.2, 77.32, 179.36), livery = 3, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1540.58, -2185.51, 77.34, 154.89), livery = 8, colors = { 111, 0 } },
                { model = 'elegy', pos = vector4(1531.66, -2184.24, 77.38, 179.36), livery = 8, colors = { 111, 0 } }
            }
        }
    }
}
