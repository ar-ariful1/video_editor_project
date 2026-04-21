-- backend/db/seeds/001_templates.sql
-- Sample template seed data for development

INSERT INTO templates (id, name, description, category, tags, template_json, aspect_ratio, duration_seconds, slot_count, is_premium, price, is_approved, is_featured)
VALUES
  (
    gen_random_uuid(),
    'Romantic Wedding Slideshow',
    'Elegant wedding photo slideshow with soft transitions and romantic music',
    'wedding',
    ARRAY['wedding','romantic','slideshow','elegant'],
    '{
      "duration": 30,
      "slots": [
        {"id":"slot_1","label":"Photo 1","type":"image_or_video","startTime":0,"endTime":3,"animations":[{"property":"scale","from":1.0,"to":1.08,"easing":"easeOut"}],"transitionOut":{"type":"fade","duration":0.5}},
        {"id":"slot_2","label":"Photo 2","type":"image_or_video","startTime":2.5,"endTime":6,"transitionIn":{"type":"slide","direction":"left","duration":0.5}},
        {"id":"slot_3","label":"Photo 3","type":"image_or_video","startTime":5.5,"endTime":9},
        {"id":"slot_4","label":"Photo 4","type":"image_or_video","startTime":8.5,"endTime":12},
        {"id":"slot_5","label":"Photo 5","type":"image_or_video","startTime":11.5,"endTime":15},
        {"id":"slot_6","label":"Photo 6","type":"image_or_video","startTime":14.5,"endTime":18},
        {"id":"slot_7","label":"Photo 7","type":"image_or_video","startTime":17.5,"endTime":21},
        {"id":"slot_8","label":"Photo 8","type":"image_or_video","startTime":20.5,"endTime":30}
      ],
      "textLayers": [
        {"id":"title","defaultText":"Your Names Here","editable":true,"startTime":1,"endTime":5,"style":{"fontFamily":"Playfair Display","fontSize":52,"color":"#FFFFFF","animIn":"fadeIn"}},
        {"id":"date","defaultText":"Wedding Date","editable":true,"startTime":25,"endTime":30,"style":{"fontFamily":"Inter","fontSize":24,"color":"#FFFFFF","animIn":"slideUp"}}
      ],
      "effects": [{"type":"lut","file":"warm_cinematic.cube","intensity":0.7}]
    }'::jsonb,
    '9:16', 30, 8, false, 0.00, true, true
  ),
  (
    gen_random_uuid(),
    'Travel Vlog Opener',
    'Dynamic travel intro with fast cuts and energetic typography',
    'travel',
    ARRAY['travel','vlog','dynamic','opener','adventure'],
    '{
      "duration": 15,
      "slots": [
        {"id":"slot_1","label":"Clip 1","type":"image_or_video","startTime":0,"endTime":3,"transitionOut":{"type":"zoom","duration":0.3}},
        {"id":"slot_2","label":"Clip 2","type":"image_or_video","startTime":2.7,"endTime":5,"transitionOut":{"type":"spin","duration":0.3}},
        {"id":"slot_3","label":"Clip 3","type":"image_or_video","startTime":4.7,"endTime":8},
        {"id":"slot_4","label":"Clip 4","type":"image_or_video","startTime":7.7,"endTime":12},
        {"id":"slot_5","label":"Clip 5","type":"image_or_video","startTime":11.7,"endTime":15}
      ],
      "textLayers": [
        {"id":"title","defaultText":"ADVENTURE AWAITS","editable":true,"startTime":2,"endTime":6,"style":{"fontFamily":"Bebas Neue","fontSize":64,"color":"#FFFFFF","animIn":"glitchReveal"}},
        {"id":"location","defaultText":"Location Name","editable":true,"startTime":8,"endTime":12,"style":{"fontFamily":"Inter","fontSize":28,"color":"#FFD700","animIn":"typewriter"}}
      ],
      "effects": [{"type":"vignette","intensity":0.4},{"type":"grain","intensity":0.2}]
    }'::jsonb,
    '9:16', 15, 5, false, 0.00, true, false
  ),
  (
    gen_random_uuid(),
    'Birthday Celebration',
    'Fun and colorful birthday video with confetti animations',
    'birthday',
    ARRAY['birthday','celebration','fun','colorful','party'],
    '{
      "duration": 20,
      "slots": [
        {"id":"slot_1","label":"Birthday Person Photo","type":"image_or_video","startTime":0,"endTime":8},
        {"id":"slot_2","label":"Memory 1","type":"image_or_video","startTime":8,"endTime":13},
        {"id":"slot_3","label":"Memory 2","type":"image_or_video","startTime":13,"endTime":20}
      ],
      "textLayers": [
        {"id":"name","defaultText":"Happy Birthday!","editable":true,"startTime":1,"endTime":7,"style":{"fontFamily":"Pacifico","fontSize":56,"color":"#FF6B9D","animIn":"bounceIn"}},
        {"id":"age","defaultText":"Turning 25 🎉","editable":true,"startTime":3,"endTime":7,"style":{"fontFamily":"Inter","fontSize":32,"color":"#FFFFFF","animIn":"fadeIn"}},
        {"id":"message","defaultText":"Wishing you all the best!","editable":true,"startTime":13,"endTime":20,"style":{"fontFamily":"Dancing Script","fontSize":36,"color":"#FFD700","animIn":"typewriter"}}
      ],
      "effects": [{"type":"lut","file":"vibrant.cube","intensity":0.6}]
    }'::jsonb,
    '9:16', 20, 3, false, 0.00, true, false
  ),
  (
    gen_random_uuid(),
    'Cinematic Film Title',
    'Hollywood-style cinematic title sequence with letterboxing',
    'cinematic',
    ARRAY['cinematic','film','title','hollywood','dramatic'],
    '{
      "duration": 12,
      "slots": [
        {"id":"bg","label":"Background Video","type":"image_or_video","startTime":0,"endTime":12}
      ],
      "textLayers": [
        {"id":"studio","defaultText":"A STUDIO PRODUCTION","editable":true,"startTime":1,"endTime":4,"style":{"fontFamily":"Oswald","fontSize":18,"color":"#CCCCCC","animIn":"fadeIn"}},
        {"id":"title","defaultText":"FILM TITLE","editable":true,"startTime":4,"endTime":10,"style":{"fontFamily":"Bebas Neue","fontSize":72,"color":"#FFFFFF","animIn":"fadeIn"}},
        {"id":"tagline","defaultText":"Tagline goes here","editable":true,"startTime":6,"endTime":10,"style":{"fontFamily":"Inter","fontSize":22,"color":"#AAAAAA","animIn":"slideUp"}}
      ],
      "effects": [
        {"type":"vignette","intensity":0.6},
        {"type":"grain","intensity":0.15},
        {"type":"lut","file":"teal_orange.cube","intensity":0.8}
      ]
    }'::jsonb,
    '16:9', 12, 1, true, 2.99, true, true
  ),
  (
    gen_random_uuid(),
    'Food Instagram Reel',
    'Mouth-watering food showcase with close-up transitions',
    'food',
    ARRAY['food','restaurant','cooking','instagram','reel'],
    '{
      "duration": 15,
      "slots": [
        {"id":"slot_1","label":"Dish 1","type":"image_or_video","startTime":0,"endTime":4},
        {"id":"slot_2","label":"Dish 2","type":"image_or_video","startTime":4,"endTime":8},
        {"id":"slot_3","label":"Dish 3","type":"image_or_video","startTime":8,"endTime":12},
        {"id":"slot_4","label":"Restaurant/Logo","type":"image_or_video","startTime":12,"endTime":15}
      ],
      "textLayers": [
        {"id":"dish1","defaultText":"Dish Name","editable":true,"startTime":1,"endTime":4,"style":{"fontFamily":"Playfair Display","fontSize":40,"color":"#FFFFFF","animIn":"fadeIn"}},
        {"id":"cta","defaultText":"Order Now 🍽️","editable":true,"startTime":12,"endTime":15,"style":{"fontFamily":"Montserrat","fontSize":36,"color":"#FFD700","animIn":"bounceIn"}}
      ],
      "effects": [{"type":"lut","file":"warm_food.cube","intensity":0.7}]
    }'::jsonb,
    '9:16', 15, 4, false, 0.00, true, false
  );

-- Update sequence counters
SELECT setval('templates_id_seq', (SELECT MAX(id::text::bigint) FROM templates) + 1) WHERE EXISTS (SELECT 1 FROM pg_sequences WHERE sequencename = 'templates_id_seq');
