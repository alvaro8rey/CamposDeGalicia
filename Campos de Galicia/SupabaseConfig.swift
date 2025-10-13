import Supabase
import Foundation

let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://ooqdrhkzsexjnmnvpwqw.supabase.co")!,  // URL de tu Supabase
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vcWRyaGt6c2V4am5tbnZwd3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYwMjk0MjEsImV4cCI6MjA2MTYwNTQyMX0.8jinhwjNaktc111FhV-_MEEiuCXynPiU88_7hMb6zcA" // Reemplaza con tu clave API pública
    )
