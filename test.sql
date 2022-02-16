SELECT t.pk_id, MAX(t.pk), MAX(t.height) as height, MAX(t.nonce) AS nonce FROM
(
WITH RECURSIVE pending_chain_nonce AS (

               (SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status

                FROM blocks b
                WHERE height = (select MAX(height) from blocks)
                ORDER BY timestamp ASC, state_hash ASC
                LIMIT 1)

                UNION ALL

                SELECT b.id, b.state_hash, b.parent_id, b.height, b.global_slot_since_genesis, b.timestamp, b.chain_status

                FROM blocks b
                INNER JOIN pending_chain_nonce
                ON b.id = pending_chain_nonce.parent_id AND pending_chain_nonce.id <> pending_chain_nonce.parent_id
                AND pending_chain_nonce.chain_status <> 'canonical'

               )

              /* Slot and balance are NULL here */
              SELECT pks.id AS pk_id,pks.value as pk,full_chain.height,cmds.nonce

              FROM (SELECT
                    id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status
                    FROM pending_chain_nonce

                    UNION ALL

                    SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status

                    FROM blocks b
                    WHERE chain_status = 'canonical') AS full_chain

              INNER JOIN blocks_user_commands busc ON busc.block_id = full_chain.id
              INNER JOIN user_commands        cmds ON cmds.id = busc.user_command_id
              INNER JOIN public_keys          pks  ON pks.id = cmds.source_id

              WHERE pks.value IN (
'B62qiWFEYUmE8pHTwqDkvCTtUANkpSYnowBRCCX4oQs8uWhidaAqSFj',
'B62qiZp8d5eBqxmhC98xXEVotZDjVyL3c4WFFR57EMaRGxERDWHpSbs',
'B62qiZtHStBhXTpsUGuhaskX9PdPKoLJ8s3QiJQM3jgzPn4AsxXepAH',
'B62qidF6QJ5AhxxsDzsBz2DURyW8rujDjJebd8C9rtsdBGB6cFMCn6J',
'B62qivMZX4JFNbtT172D7xbunHkxChtwvnf9TBUdaPFAj2AkRNXVkCr',
'B62qiy6Y5GK9Q7mvaE76a3zxzPjq3Rd6JJJsK2TcqXBLu3fVhf5n9KL',
'B62qjEXf5hjUgH55meDhnoxrL5dhYEpiF4ZPSxtx6uZHY6Z3cXmPWSM',
'B62qjJQ8Up2zUVgax2PwoYyDJ4mTq8japh9vt3gBoBWY5ubN7m2yuTf',
'B62qjJfGhzuRVMujRKF1QoS6t5FLBBbJM9Znho8FxadNr5GTueWMX5o',
'B62qjJkK7o2NfomTqQ9CGw6hQut9zLdYZ3aTk8ejm8wCfao421JC4md',
'B62qjKFD2GzWB2gXaG6qpkBishaFDWRdERXKiRs8xGM6LG3VAz4YPQj',
'B62qjR6x6zUC7zv43h7VNDh1DBBWfo54W4TVCPjBWo1AkJaw34XBsBZ',
'B62qjRAArE8hJMj8BdqiBqaZ5QSjAYvpb1N7ZcgM6wUSzaqeDTfoWHt',
'B62qjS2aumQHGA2BmYWYunN8ctn9cKDprub1dkW68zxKTWmWbBQKJ3Z',
'B62qjf8234PiyaiMBmjxznhwDFPcjbF2kH9JZNYHjuxRooW4CXtGGRh',
'B62qjwyr3t91g15k8xt9WagionL1cyg18A3Chf2TtQy3onJbY6rWDA8',
'B62qjxMvVeRCVriY3nuU5Tzu7PMdfgwjcQrPj15Tsemg1pNzALTH9U4',
'B62qkEAUy4CYYqcxVv3jkkPRLjTfCmtAnsYu3SXMykByEG4UHny7y89',
'B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk',
'B62qkcQuZedDN8kmbnRYJXnaWAJDN81AVZyZ2b2JYJzzqb14Er5cd3v',
'B62qkd6yYALkQMq2SFd5B57bJbGBMA2QuGtLPMzRhhnvexRtVRycZWP',
'B62qkg7mcYbwnui3xYRAhmBtV3qR6QTojFqTMNTMCZ4yCEVC3N7m4kT',
'B62qkhA4FLonB9FDmxQG9awSVApEGkKo2drUksURKCBGF1WidbjK7kF',
'B62qknDo78x7AAfCE3oXtif7oKnshAXwrSzXWgLPrtxKsH4agEPCyHq',
'B62qkrPaKPKveAE8ufXUS6ViJnAFLQLLz29J9KUjJCVnA1sCvATTcqd',
'B62qkw8fmgchgwEQ9qTpEuTtLCnYTQxSBo4VDkfuZCCE5ea2HcKJ8mA',
'B62qm6Ybxc4i7ih4Ti5yGXNNDxkQDNKCvEax9iHfZeZuor16hH3i4Kx',
'B62qmQsEHcsPUs5xdtHKjEmWqqhUPRSF2GNmdguqnNvpEZpKftPC69e',
'B62qmVRowS3PAaXqSdA4PBi5Y5eNmrZuBBN84SNJXiwpB5cRFyZEz4z',
'B62qmoKG8Hb9iq1PscaUKKGV6XCZzE2oMzTrmq9opLtu6xfZc5iDsno',
'B62qmrnwGZXdg3j6E3Dqnzy9iYJr4JUfoAp4aN7e5X1yCc2ZkC61eP5',
'B62qn1EVFyCwL4mgBYveF3DNEieNvJzv6CtQBmYSp1EH5BABSb2aXfk',
'B62qn9n8i5ADsjG9FxYpt3iLUpAvfcjSru2u3NEeBCbSyFGJBtDPyxp',
'B62qnBGeNaar596N9j8hKGUTm6fZiVbYRH7A2GbU6tNMaE7zLZXxuXt',
'B62qnBmZeUT6qt7Cq9D6GM7fdk7DRe9fvjtANY6cp4sy8jXV5d9ksho',
'B62qnEdPB1V5YPEcGaETb19naLJV6sWdveCZEjSLhcVyrPcPWHkGGax',
'B62qnFKLqyUuAiEKG8A5PM6rLkyi3YABeTfG9zKQ6sMGcxffH2N6Uwn',
'B62qnKLwR4edik6WqLy4VcK7fmusnkNnvfUh3W6onx4r8FehLqyGLrZ',
'B62qnLVz8wM7MfJsuYbjFf4UWbwrUBEL5ZdawExxxFhnGXB6siqokyM',
'B62qnNjzScBuJNA78nZ2CSihG7Z4dNPdj66NpJW38fNSRmSTPHk1WCC',
'B62qnnLsSHb9S99R5HnkXUpX3YYnXHmLiagtvkMr3kSWuhcbmB9kDcN',
'B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV',
'B62qoBEWahYw3CzeFLBkekmT8B7Z1YsfhNcP32cantDgApQ97RNUMhT',
'B62qoBk6uRcKJyx4LvogKBhm2CLkxBh11AxivDHnXAyigSENbHDkk4U',
'B62qoE6Y2gYLrHXVAA14cqeM5vCgwCvd4HkF8FTpitaABDP1fjDdmWX',
'B62qoHTro3XNhN3HunUbD3sYzcPxBVUjTZkpmhnD4bpu2r95N6qobUR',
'B62qoQSggXskw3YQjTCmi24Yh9HuuiXBSBKDKzgyxg1G7oe3ng2r4jo',
'B62qobP7E6guGwRGFkZo4PoLFGHYDEdHjDRpktfLsL16WKPatxkwXgr',
'B62qocLEcZH4yRJMjRvrUnjkWnnZG6mrR3Y1R5Svcm4TnSgLfCiRW87',
'B62qoeMGjqqoXfH1JcUirKBjzWYAi8RqrRYxMdQd9a3DtpLfzG9JTMW',
'B62qonwi1K1s7ZU77ifRyxnCfNyWZeUCkz9WiM9a54vejGmiwZBygf8',
'B62qooQQ952uaoUSTQP3sZCviGmsWeusBwhg3qVF1Ww662sgzimA25Q',
'B62qopfPEziMiDnePu7wt4DoJwGwkh1iLn45jXoVrpHbtMXSdgJGxT2',
'B62qp3B9VW1ir5qL1MWRwr6ecjC2NZbGr8vysGeme9vXGcFXTMNXb2t',
'B62qpAiHfNJYiumu92AA3dL6ZS1LURN5snXBPxJo6sctjKJ6zxwTcVZ',
'B62qpBj7iGz2qxPP8Yj2xywWmdc3X5tpPhj8H4Zc83R3561xKAA1Mv5',
'B62qpNqyLtWwcpYv36PsxvPu7dmNcYP9J4X6B9Mv4vA7XnBjicC62kN',
'B62qpefWBWeg3t4UN1Lb3XYLJHesD5smJcQEwVHTuaKSPWVpiQaqqNq',
'B62qpjxUpgdjzwQfd8q2gzxi99wN7SCgmofpvw27MBkfNHfHoY2VH32',
'B62qq1FJ8MTBcPsJkZFKoVA9JNSiKCbXFABYs85i8MZPtA9Qzt9mLDj',
'B62qqD7SNr7EPxvkz3RKUwBzHXgd5snsmSQsqw96kEeRTmsn8e8w2Kk',
'B62qqUzbYrM5AXwAXLHZF4ZMNTyEFPKga9NJeASP7LWaHfjTiZwM9J3',
'B62qqfv5ce6dwyLevtNoqrL1iDZdQHgGm2C3ZMm4kudrmowtH3WtF1K',
'B62qqmJT6fWVfnxs7Zyg4V6HjQpbWXh9pfYum9CB6efZf9nbQkJvTA8',
'B62qqnheuZNeSgy75dvuvrr7KUWTEYwtQgyr6x61v7QNNUyVwuarAFU',
'B62qqtBH38HUFHLuAowgvC3YgLy78aGCY9qPSmVhPU9niwGeLi4PryX',
'B62qqukEJc1AYbuUEBcvGfBKQt8AGgwYwpnewyh7qzxTTz4bnifJdwo',
'B62qr9W7GPFhhtTQutbGprKh1F8BikTAxf5jS6ekTNNAjCMjsgqevDP',
'B62qrA2EDD59atmsd2rPi7wMC2Z5Ltu3XYDCacpVu647nVe8J8TR3Cv',
'B62qrBVGw3GLLowVUt9WM3UbCSjBdmSheQ3FjmzjVFrbnmJrWxzFDqm',
'B62qrC4ZJRQxQXNues3K8funCxZzasfCaPiP9a2NuZ7kuxJdHuzX1v7',
'B62qrLUjcNMy2MMcJVVnAMMeWYod6fj2srNxney6DGWwYosqw3AqMUi',
'B62qrPxULZ8rNicd2YKQo9n5NNMqJjP9xgH7U3sscRsaRMr12v4L1wg',
'B62qrrBDgQpn8qMDBmKL6nSLX7LYdRgCeXa5p2FnMumYxcvhGPRwgs5'
                )
              AND busc.user_command_id = cmds.id

              ORDER BY (full_chain.height, busc.sequence_no) DESC
            ) t
            GROUP BY t.pk_id LIMIT 80
