/**
 * For reference only
 * See life.s for the actual implementation
 */
uint8_t life(uint8_t world[], uint8_t x_size, uint8_t y_size)
{
	int world_size = x_size * y_size;
	uint8_t new_world[world_size];
	uint8_t x = 0;
	uint8_t y = -1;
	for(int i = 0; i < world_size; i++, x++)
	{
		//Identify eight neighbours of each index
		//1. x + 1, unless overflow, then x = 0
		//2. x - 1, unless underflow, then x = x_size - 1
		//3. y + 1, unless overflow, then y = 0
		//4. y - 1, unless underflow, then y = y_size - 1
		//5. x + 1, y - 1, underflow, overflow, yada, yada...
		//6. x - 1, y - 1
		//7. x - 1, y + 1
		//8. x + 1, y + 1
		uint8_t live_neighbour_count = 0;
		uint8_t neighbour_idx[8] = {
			i + 1,            //RIGHT
			i - 1,            //LEFT
			i + x_size,       //DOWN
			i - x_size,       //UP
			i + x_size + 1,   //DOWN-RIGHT
			i - x_size + 1,   //UP-RIGHT
			i - x_size - 1,   //DOWN-LEFT
			i + x_size - 1,   //UP-LEFT
		};
		
		if(x == (x_size - 1))
		{
			x = 0;
			neighbour_idx[0] -= x_size;
			neighbour_idx[4] -= x_size;
			neighbour_idx[5] -= x_size;
		}
		else if(x == 0)
		{
			neighbour_idx[1] += x_size;
			neighbour_idx[6] += x_size;
			neighbour_idx[7] += x_size;
			y++;
		}
		if(y == (y_size - 1))
		{
			neighbour_idx[2] -= (world_size - x_size);
			neighbour_idx[4] -= (world_size - x_size);
			neighbour_idx[7] -= (world_size - x_size);
		}
		else if(y == 0)
		{
			neighbour_idx[3] += (world_size - x_size);
			neighbour_idx[5] += (world_size - x_size);
			neighbour_idx[6] += (world_size - x_size);
		}
		
		for(n = 0; n < 8; n++)
		{	
			if(1 == world[neighbour_idx[n]])
			{
				live_neighbour_count++;
			}
		}

		if(live_neighbour_count < 2)
		{
			new_world[i] = 0;
		}
		else if(live_neighbour_count == 2)
		{
			new_world[i] = world[i];
		}
		else if(live_neighbour_count == 3)
		{
			new_world[i] = 1;
		}
		else
		{
			new_world[i] = 0;
		}
	}


	return new_world;
}
