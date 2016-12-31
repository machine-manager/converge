alias Gears.FileUtil
alias Converge.{GPGSimpleKeyring, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.GPGSimpleKeyringTest do
	use ExUnit.Case, async: true

	@wine_ppa_key """
	-----BEGIN PGP PUBLIC KEY BLOCK-----
	Version: GnuPG v2

	mQINBFZQ6XIBEAD5/TaUNm7zYtGSFXVMCZJTvi+vtTYluYO0DLT4q7kxUsqqz6xe
	5Q4xbpyyw71twvvW6lOXJ9v0X8jbI4lA/HvI6fuHM9veZPs4NKdIYWKpKoe7Hpvw
	wKg1QJwcTdHkgqwgIm5lmoO4wzeewymBXLgeDbkkOnzyBJECwBVulj/f/6RQRYWg
	tH4VRVVkUai4K/Yh99U3iSv+RL5cB+QqJr6lh/IBGJZYGidCW3eXgOXAjCJ4PROG
	FvRkrbOGQuhQzdsYh9pgSHKmWLeor5Hlpp8bxPwtwicMS5hJO1d9D/Z2FvaVaAP9
	ilbMUF+xCXRy3Hocgo7dv0meq/vlKlBNG2ZlZETjOrRkmn68kD0O62XSxYsV0t+9
	syKfgX8c88Ba4g0FMY7iXGz/4w3slq1EEdp88snitmtqj2xtnb26RqUQOQlqQw5/
	OkiyJmj4Xn1aAiUuOICri+PCZI+/CNQz9rout+oeEeT5xX45sw6Gl0v5oTeGtiNC
	OQkTchmHCK9jBKjnNAq/q2VCvZVZpvhLHcY9i1O+Glh41HRkrDJTgITH6mylv6yj
	oA13mPECEsYojFN8QmJGL4F2n3N36qWokFM9dUCyJuhH5SThLzYN7iM1gSKC9EIu
	dknY4SaVrrSM7CZt5mFq+73dGRzOHa+hRIgs3R1Ag0MmNmEFJJxfkZGhEwARAQAB
	tBZMYXVuY2hwYWQgUFBBIGZvciBXaW5liQI4BBMBAgAiBQJWUOlyAhsDBgsJCAcD
	AgYVCAIJCgsEFgIDAQIeAQIXgAAKCRDmGiTfd8iZy+9nEACyUpQr5YHuVp7/Uc26
	beRQcREg2ruO5X8DJowXg0JShH3UIpuCPotqCO+GqpaquJqENGKJEaMPIOo8FOU3
	J3lmOY+5k9RST8ZHrD3NNw3AYsrGNEuq5NAoBrGAwvRD5BbnX14okcJO7vbVteP6
	8rFROBaMnXZxZWxk5vuQD+VlyqoS6UZLtXBEdB7JXh+OlPoiIeC8Uw8YzIsaf78k
	bNmAAXaVlNJKTKiH13q15oFSFr1UfCMdk3kAHouhP0YigwfxwUPh9yoYhw4qSQ1d
	1VAi4cbzmGGNE6fxVP9hkwKqeYUPk/2Twzb/BwsQSZ/x8pp7tftJvnWhPvV08wlq
	MmOiQ1+wpYZTP38dILnq0VzrE8YprxSiYMrzHQeP/E3btB9/LflCvkFhQDTDJ0sg
	VFqtEvdn/kOd2ub9RMfzDBX4e188mkzbTkydtptPVEm7GFg45hBSQFJuwpcGw+NO
	lNjDNX6v3E2fXbA647qeCfmg/VaYVsWZdCJzd38Gzsp5doTVXualuL91eVkLbrUQ
	MZd6cBsFhLxIUdMXjtiZ1vHUqdZxcEJuVR88Z76TrUGQ1o/B47PytWLnF/IPwA8v
	jXzDsBBjbHTJf2hTN4KEJmEMu2PU24abzf8F4e9so7mzmDYtsiSLRMQt4A+f6waZ
	0qRwqJB65TgNfnLv3RAXTQQUAg==
	=nKFM
	-----END PGP PUBLIC KEY BLOCK-----
	"""

	@graphics_drivers_ppa_key """
	-----BEGIN PGP PUBLIC KEY BLOCK-----
	Version: GnuPG v2

	mQINBFXLUXIBEADggY4UTKq5jU0lYFAzC4g7iB50aRgJRA+nL9NkrHamdtNggfVy
	wzflQYJ4w96FV5p5j+9Nvdfk5ZPHe+uVmaC5AUdId2G+zzG/fsf3Ri9hz61sYg4M
	8DyRZDh9KLqr+x7AazAHjmqwLecT/sNHdwHFdduQcvvkwfMw8JUN6IIRrbT3ISoZ
	gaktuF8EfFuc/PKoCoHWXjgVqw/JDjpL/1LHyMwYWfZgrG41PqRSxI9/dKt0W7XX
	dOEckHTjV6IZkVCYCBMcObM2ZLSMVb0u9SlTOUIHaF3A2IY+9RLpUAa8bZLodiXa
	lfQ9OmvQm+eIXOedzBhs2z7hGBJwcCGW94cVygWUyakfsxCqPF4+VJHKnEgp/kkP
	NV3i/XOlMOzzq7TZQjNXTnIkqhe99R3C2sVSRh8GcHvSl1eKh+PkRjJ1amSx8u2m
	eT5xxKLcfgM4RoVkujGetNSLiJmv721JGChXixLa0flL8Rfe7vVB08gzBdb+1KLm
	+NW8VBAhs3ectycuAn/OlqN+g3Pww0CXKHRgDKXkMDtLoPNzMjPi7bBcP5OP3tvB
	NBLJx12BEGZweDgpIYUAAC++yHvYVj5s4fYDDBC6gOAqeV+jwibt5kwopBr8yrc4
	3eZf1iluZmmi62BgOpk3M9/kIdhFO4WlMLfeJ7YYz69CLCED/680yf8UywARAQAB
	tCdMYXVuY2hwYWQgUFBBIGZvciBHcmFwaGljcyBEcml2ZXJzIFRlYW2JAjgEEwEC
	ACIFAlXLUXICGwMGCwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEPyuEQsRGCE8
	WYAQAKSG+fpQ0hABy5R7UdW8Mv1L9KD3XAfBAeS3xRLdcZVLwD6pnviRdj8pTZTy
	Z4taL9AOpJcskVu/MbQYfAc/UY/qP6uxTr7Ei1xeEKPrpITmTRPzVBUgcIvHydiI
	uZZ60fnpryCSSjoHna2ltFd0E1zEHPA8RsPn9CjChZJzTD1vyAS7zwhqGtS4fHrS
	HiOCEYvobLaodN9mNPw/2OcgatSwBgA0hKnNtMe1VFKUx1GH2mJoL59NDFVueIsd
	bUOPQLfMhWnfAE3tKOSklKNz1IvBK6XcSDKAN6X/8oiaSWvGQZwKj+4ToeKDEvXj
	vSxyP2SQSjHHKgV4M4eBSTIZbxIrzJ//OqfMN7bFPVJwPlcVlBZU2A7uSuCUWey0
	lXwH5YtdifiSN1+ctiiLBSEuwiFPdQZT552lrqAHF8586lgTOwZ7sEJTZwUtD4zH
	peri4V3Nn/fNA02maamHg7i/BDibdH+r8wEpdz0zMGCpHEeyOJ3dIfJ9FbD0VJAq
	RIM9GTCwSWmEgsTOQLG9BCP+9WzbPG1IUOBaJaUm4VBw3x8OTBrtmzS/MnKtU/2W
	/iz3NJ1AZ2tBAbaTNGI5fFl2ZW+r65iMBwYZ/oIOzlU5SnNSLNW3MmDUNMv22iaP
	K18Z3EYaGv8JhYO5KF4o1aeb/d5f7pVA52GCkSd3wwIK39PW
	=QFVe
	-----END PGP PUBLIC KEY BLOCK-----
	"""

	test "empty keyring" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGSimpleKeyring{path: p, keys: [], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end

	test "keyring with one key" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGSimpleKeyring{path: p, keys: [@wine_ppa_key], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end

	test "keyring with two keys" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGSimpleKeyring{path: p, keys: [@wine_ppa_key, @graphics_drivers_ppa_key], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end
end
