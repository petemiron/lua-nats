package.path = '../src/?.lua;src/?.lua;' .. package.path

pcall(require, 'luarocks.require')

local telescope = require 'telescope'
local nats = require 'nats'

local settings = {
    host = '127.0.0.1',
    port = 4222,
}

-- ### Basic table handling methods ###

function table.keys(self)
    local keys = {}
    for k, _ in pairs(self) do table.insert(keys, k) end
    return keys
end

function table.values(self)
    local values = {}
    for _, v in pairs(self) do table.insert(values, v) end
    return values
end

function table.contains(self, value)
    for _, v in pairs(self) do
        if v == value then return true end
    end
    return false
end

telescope.make_assertion('error_message', 'result to be an error with the expected message', function(msg, fn)
    local ok, err = pcall(fn)
    return not ok and err:match(msg)
end)

-- ### Tests ###

context('Client initialization', function()
    test('* Can connect successfully', function()
        local client = nats.connect(settings.host, settings.port)
        assert_type(client, 'table')
        assert_true(table.contains(table.keys(client.network), 'socket'))
        -- Before the connection, the server information is not found in the client
        assert_false(table.contains(table.keys(client.information), 'host'))
        assert_false(table.contains(table.keys(client.information), 'port'))

        client:connect()
        -- After the connection, the server information is stored in the client
        assert_true(table.contains(table.keys(client.information), 'host'))
        assert_true(table.contains(table.keys(client.information), 'port'))
    end)

    test('* Accepts a table for connection parameters', function()
        local client = nats.connect(settings)
        assert_type(client, 'table')
    end)

    test('* Can handle connection failures', function()
        assert_error_message('could not connect to .*:%d+ %[connection refused%]', function()
            nats.connect(settings.host, settings.port + 50)
        end)
    end)
end)

context('NATS commands', function()
    before(function()
        client = nats.connect(settings)
        client:connect()
    end)

    test('* CONNECT (client:connect)', function()
        assert_equal(client.network.lwrite:sub(1,7), 'CONNECT')
        assert_equal(client.network.lread:sub(1,4), 'INFO')
    end)

    test('* PING (client:ping)', function()
        assert_true(client:ping())
        assert_equal(client.network.lwrite:sub(1,4), 'PING')
        assert_equal(client.network.lread:sub(1,4), 'PONG')
    end)

    test('* PONG (client:pong)', function()
        client:pong()
        assert_equal(client.network.lwrite:sub(1,4), 'PONG')
    end)

    test('* SUB (client:subscribe)', function()
        local subject, callback = 'subject', function(msg,inbox) print(msg) end
        local subscribe_id = client:subscribe(subject, callback)

        assert_true(subscribe_id ~= '')
        assert_equal(client.network.lwrite:sub(1,3), 'SUB')
    end)

    test('* UNSUB (client:unsubscribe)', function()
        local subject, callback = 'subject', function() return end
        local subscribe_id = client:subscribe(subject, callback)
        client:unsubscribe(subscribe_id)

        assert_equal(client.network.lwrite:sub(1,5), 'UNSUB')
    end)

    test('* PUB (client:publish)', function()
        local subject, payload = 'subject inbox', 'payload'
        client:publish(subject, payload)

        assert_equal(client.network.lwrite:sub(1,3), 'PUB')
    end)
end)
