#pragma once
// Public values only. The publishable key is designed to live inside apps; row-level security protects the data.
// NEVER put the secret / service_role key or the database password in this file.
inline constexpr const char *kSupabaseUrl = "https://mljdegznscdoctiizyij.supabase.co";
inline constexpr const char *kSupabaseKey = "sb_publishable_Kr-r4bv6fra9NbkDGazdDw_jBQ_x3lk";
// Usernames are stored as made-up addresses because sign-in is username + password only.
inline constexpr const char *kEmailDomain = "users.invalid";
