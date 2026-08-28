-- Local dev seed data.
--
-- Releases domain: deliberately includes 1.9.0 / 1.10.0 / 2.0.0 so that
-- semver-aware sorting (vs. lexicographic sorting, which would put 1.10.0
-- before 1.9.0) is exercised by anyone poking at the local DB, and is
-- asserted in supabase/tests/database/releases_functions.sql.

insert into releases.engine_releases
(version, version_major, version_minor, version_patch, release_date, release_notes_summary, status)
values
  ('1.2.0',  1, 2,  0, '2026-03-01', 'Initial public renderer preview.',        'deprecated'),
  ('1.3.0',  1, 3,  0, '2026-05-15', 'Vulkan swapchain stability fixes.',       'stable'),
  ('1.4.0',  1, 4,  0, '2026-07-10', 'Qt6 editor integration.',                 'stable'),
  ('1.9.0',  1, 9,  0, '2026-08-01', 'FFI layer expansion.',                    'stable'),
  ('1.10.0', 1, 10, 0, '2026-08-15', 'VFS and logging bridges.',                'stable'),
  ('2.0.0',  2, 0,  0, '2026-08-28', 'Major architecture revision.',            'beta');

insert into releases.engine_artifacts
(release_id, os, architecture, download_url, sha256, size_bytes, min_requirements, compiler)
select r.id, v.os, v.architecture, v.download_url, v.sha256, v.size_bytes,
       v.min_requirements::jsonb, v.compiler::jsonb
from releases.engine_releases r
       join (values
               ('1.3.0',  'windows', 'x86_64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v1.3.0/coreverse-engine-windows-x86_64.zip',
                '1950e0f4afd384b7abe4cec726b5e9aa5aa80710df830e881f7019dd60144b3d',
                184320000,
                '{"os":{"name":"windows","version":"10"},"cpu":{"architecture":"x86_64","cores":4},"ram_gb":8,"disk_gb":15,"gpu":{"required":true,"api":"vulkan","vram_gb":2}}',
                '{"name":"msvc","version":"19.38"}'),

               ('1.4.0',  'windows', 'x86_64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v1.4.0/coreverse-engine-windows-x86_64.zip',
                '977ab8228b6695bb71bdb321a562f4c3a2236a1bb8767e14bf1ad790230fea2a',
                191234000,
                '{"os":{"name":"windows","version":"10"},"cpu":{"architecture":"x86_64","cores":4},"ram_gb":8,"disk_gb":15,"gpu":{"required":true,"api":"vulkan","vram_gb":2}}',
                '{"name":"msvc","version":"19.40"}'),
               ('1.4.0',  'linux',   'x86_64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v1.4.0/coreverse-engine-linux-x86_64.tar.gz',
                '11ef107963933e4b2376e5d30e6da6579e56be8f217b57ace51069f2cc152464',
                178900000,
                '{"os":{"name":"linux","version":"22.04"},"cpu":{"architecture":"x86_64","cores":4},"ram_gb":8,"disk_gb":15,"gpu":{"required":true,"api":"vulkan","vram_gb":2}}',
                '{"name":"gcc","version":"13.2"}'),

               ('1.10.0', 'windows', 'x86_64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v1.10.0/coreverse-engine-windows-x86_64.zip',
                'f9940e9492bf56cdffc77dbb3a4555b8cfd7af3a3812bbe8b0b5f38c08a3e692',
                198765000,
                '{"os":{"name":"windows","version":"11"},"cpu":{"architecture":"x86_64","cores":4},"ram_gb":8,"disk_gb":20,"gpu":{"required":true,"api":"vulkan","vram_gb":4}}',
                '{"name":"msvc","version":"19.44"}'),
               ('1.10.0', 'macos',   'arm64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v1.10.0/coreverse-engine-macos-arm64.zip',
                'fd09277561013dd2bf16ea2015dda879dfdd1ad3849bdc391b296be86eaf7bae',
                165432000,
                '{"os":{"name":"macos","version":"14"},"cpu":{"architecture":"arm64","cores":4},"ram_gb":8,"disk_gb":20,"gpu":{"required":true,"api":"vulkan","vram_gb":4}}',
                '{"name":"apple-clang","version":"16.0"}'),

               ('2.0.0',  'windows', 'x86_64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v2.0.0/coreverse-engine-windows-x86_64.zip',
                '499d7cd584bd2a32db82d81299dc46e6731194c143160a56075e25addf2a0be4',
                205000000,
                '{"os":{"name":"windows","version":"11"},"cpu":{"architecture":"x86_64","cores":6},"ram_gb":16,"disk_gb":25,"gpu":{"required":true,"api":"vulkan","vram_gb":4}}',
                '{"name":"msvc","version":"19.44"}'),
               ('2.0.0',  'linux',   'x86_64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v2.0.0/coreverse-engine-linux-x86_64.tar.gz',
                '93d44ab3f3fd09cf568953ed4c7bec6f9a136497dc3706b8f621c4621a4c5a7d',
                199870000,
                '{"os":{"name":"linux","version":"22.04"},"cpu":{"architecture":"x86_64","cores":6},"ram_gb":16,"disk_gb":25,"gpu":{"required":true,"api":"vulkan","vram_gb":4}}',
                '{"name":"gcc","version":"14.1"}'),
               ('2.0.0',  'macos',   'arm64',
                'https://github.com/KING-MASTER2012/Coreverse-Engine/releases/download/v2.0.0/coreverse-engine-macos-arm64.zip',
                'aad5fda0d3d189655bbc3278b42bbc90653bdf28c22c3cac54d66664a58a3fd2',
                172345000,
                '{"os":{"name":"macos","version":"14"},"cpu":{"architecture":"arm64","cores":6},"ram_gb":16,"disk_gb":25,"gpu":{"required":true,"api":"vulkan","vram_gb":4}}',
                '{"name":"apple-clang","version":"16.0"}')
) as v(version, os, architecture, download_url, sha256, size_bytes, min_requirements, compiler)
            on v.version = r.version;
