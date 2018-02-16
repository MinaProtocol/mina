/** @file
 *****************************************************************************

 Implementation of functions for profiling menu.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <cmath>
#include <ctime>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>

#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>

/* Level 2: Profile */
void profile()
{
  std::cout << "\n\033[1;32mChoose Profile Type:\033[0m\n";
  std::cout << "\033[1;32m(i.e. To Select All, input '1 2 3')\033[0m\n\n";
  std::cout << "\033[1;36m 1: Runtime\033[0m\n";
  std::cout << "\033[1;36m 2: Memory\033[0m\n";
  std::cout << "\033[1;36m 3: Operators\033[0m\n";
  std::cout << "\033[1;36m 4: (Back)\033[0m\n\n";

  int valid_input = 0;
  std::string profile_type;
  do {
    std::cout << "> ";
    getline(std::cin, profile_type);

    /* Check Input Validity */
    int n;
    valid_input = 1;
    std::stringstream stream(profile_type);
    while (stream >> n)
    {
      if (n < 1 || n > 4) valid_input = 0;
      if (n == 4) valid_input = 2;
    }
  } while (!valid_input);

  /* Level 3: Choose Domain Type */
  if (valid_input == 1)
  {
    std::cout << "\n\033[1;32mChoose Domain Type:\033[0m\n\n";
    std::cout << "\033[1;36m 1: All\033[0m\n";
    std::cout << "\033[1;36m 2: Radix-2\033[0m\n";
    std::cout << "\033[1;36m 3: Arithmetic & Geometric\033[0m\n";
    std::cout << "\033[1;36m 4: (Back)\033[0m\n\n";

    valid_input = 0;
    std::string domain;
    do {
      std::cout << "> ";
      getline(std::cin, domain);

      int n;
      valid_input = 1;
      std::stringstream stream(domain);
      while (stream >> n)
      {
        if (n < 1 || n > 4) valid_input = 0;
        if (n == 4) valid_input = 2;
      }
    } while (!valid_input);
    int domain_type = atoi(domain.c_str());

    /* Level 4: Choose Domain Sizes */
    if (valid_input == 1)
    {
      /* Built-in domain size choices */
      std::vector<std::string> domains(3);
      domains[0] = "32768 65536 131072 262144";
      domains[1] = "131072 262144 524288 1048576";

      std::cout << "\n\033[1;32mChoose Domain Sizes:\033[0m\n\n";
      std::cout << "\033[1;36m 1: Small - [" << domains[0] << "]\033[0m\n";
      std::cout << "\033[1;36m 2: Large - [" << domains[1] << "]\033[0m\n";
      std::cout << "\033[1;36m 3: Custom\033[0m\n";
      std::cout << "\033[1;36m 4: (Back)\033[0m\n\n";

      do {
        std::cout << "> ";
        getline(std::cin, domain);
      } while (strcmp(domain.c_str(), "1")
            && strcmp(domain.c_str(), "2")
            && strcmp(domain.c_str(), "3")
            && strcmp(domain.c_str(), "4"));
      int domain_choice = atoi(domain.c_str()) - 1;

      if (domain_choice >= 0 && domain_choice < 3)
      {
        /* Level 5: Custom Domain Choice */
        if (domain_choice == 2)
        {
          std::cout << "\n\033[1;32mEnter Custom Domain:\033[0m\n";
          std::cout << "\033[1;32m(i.e. \"32768 65536 131072 262144\")\033[0m\n\n";
          std::string custom_dom;
          bool custom_input = 0;
          do {
            std::cout << "> ";
            getline(std::cin, custom_dom);

            /* Check Input Validity */
            if (strcmp(custom_dom.c_str(), "") && strcmp(custom_dom.c_str(), " "))
            {
              std::stringstream stream(custom_dom);
              custom_input = 1;
              int n;
              while (stream >> n) if (n < 1) custom_input = 0;
            }
          } while (!custom_input);
          domains[2] = custom_dom;
        }

        /* Get Current Timestamp */
        time_t rawtime;
        time(&rawtime);
        struct tm* timeinfo = localtime(&rawtime);
        char buffer[40];
        strftime(buffer, 40, "%m-%d_%I:%M", timeinfo);
        std::string datetime(buffer);

        /* Perform Profiling */
        std::cout << "\n\033[1;32mStarting Profiling:\033[0m\n";
#ifdef PROF_DOUBLE
        printf("Profiling with Double\n");
#else
        printf("Profiling with Fr<edwards_pp>\n");
#endif
        for (int threads = 0; threads < 4; threads++)
        {
          for (int key = 0; key < 4; key++) /* Change key to 5 for arithmetic domain */
          {
            if (key > 2 && domain_type == 2) continue;
            if (key < 3 && domain_type == 3) continue;
            if (system(("./profiler "
                        + std::to_string(key) + " "
                        + std::to_string(pow(2, threads)) + " "
                        + datetime + " "
                        + "\"" + profile_type + "\" "
                        + "\"" + domains[domain_choice] + "\"").c_str()))
              printf("\n error: profiling\n");
          }
        }
        std::cout << "\n\033[1;32mDone Profiling\033[0m\n";
      }
    }
  }
}

/* Level 2: Plot */
void plot()
{
  std::cout << "\n\033[1;32mChoose Profile:\033[0m\n\n";
  std::cout << "\033[1;36m 1: Operators\033[0m\n";
  std::cout << "\033[1;36m 2: Runtime\033[0m\n";
  std::cout << "\033[1;36m 3: Memory\033[0m\n";
  std::cout << "\033[1;36m 4: (Back)\033[0m\n\n";

  int type;
  std::string res;
  do {
    std::cout << "> ";
    getline(std::cin, res);
    type = atoi(res.c_str());
  } while (type < 1 || type > 4);

  /* If not (back) option */
  if (type > 0 && type < 4)
  {
    /* Source Directory */
    std::vector< std::string > path (3);
    path[0] = "libfqfft/profiling/logs/operators/";
    path[1] = "libfqfft/profiling/logs/runtime/";
    path[2] = "libfqfft/profiling/logs/memory/";

    std::vector< std::string > gnufile (3);
    gnufile[0] = "libfqfft/profiling/plot/operators_plot.gp";
    gnufile[1] = "libfqfft/profiling/plot/runtime_plot.gp";
    gnufile[2] = "libfqfft/profiling/plot/memory_plot.gp";

    /* Level 3: File to Plot */
    DIR *dir;
    if ((dir = opendir(path[type - 1].c_str())) != NULL)
    {
      std::cout << "\n\033[1;32mSelect File to Plot:\033[0m\n\n";

      int count = 1;
      struct dirent *pDirent;
      std::vector<char*> files;
      while ((pDirent = readdir(dir)) != NULL)
      {
        if (pDirent->d_name[0] != '.')
        {
          files.push_back(pDirent->d_name);
          std::cout << "\033[1;36m "<< count++ << ": " << pDirent->d_name << "\033[0m\n";
        }
      }
      std::cout << "\033[1;36m " << count << ": (Back)\033[0m\n\n";
      closedir(dir);

      /* Select File to Plot */
      int file_number;
      std::string file;
      do {
        std::cout << "> ";
        getline(std::cin, file);
        file_number = atoi(file.c_str());
      } while ((file_number > 0 && file_number <= ((int) files.size()) + 1) ? 0 : 1);

      if (file_number < count)
      {
        /* Log Files Path */
        std::string log_path = path[type - 1] + files[file_number - 1];
        /* System Call */
        std::string cmd = "gnuplot -e \"input_directory=\'" + log_path + "\'\" " + gnufile[type - 1];
        if (system(cmd.c_str()) == 0) printf("Plotted in %s\n", log_path.c_str());
      }
    }
  }
}

/* Level 1: Choose to Profile or Plot */
int main()
{
  bool resume = 1;
  while (resume)
  {
    std::cout << "\n\033[1;32mChoose:\033[0m\n\n";
    std::cout << "\033[1;36m 1: Profile\033[0m\n";
    std::cout << "\033[1;36m 2: Plot\033[0m\n";
    std::cout << "\033[1;36m 3: Exit\033[0m\n\n";

    std::string res;
    do {
      std::cout << "> ";
      getline(std::cin, res);
    } while (strcmp(res.c_str(), "1")
          && strcmp(res.c_str(), "2")
          && strcmp(res.c_str(), "3"));

    if (strcmp(res.c_str(), "1") == 0) profile();
    else if (strcmp(res.c_str(), "2") == 0) plot();
    else if (strcmp(res.c_str(), "3") == 0) resume = 0;
  }

  return 0;
}
