using Test
using OliveCollaborate
using OliveCollaborate.Olive
OliveCollaborate.Olive.start("127.0.0.1":8000, headless = true)

@testset "olive collaborate load test" begin
    newkey = Olive.CORE.users[1].key
    @test length(newkey) > 0
    @warn newkey
    ret = Olive.Toolips.get("http://127.0.0.1:8000/key?q=$newkey")
    ret = Olive.Toolips.get("http://127.0.0.1:8000/")
    @test contains(ret, "sendpage")
end